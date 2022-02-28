Hello everyone! 👋

Thanks for the amazing job done with BLoC and I hope you will find this proposal interesting.

🚧Disclamer🚧

I'm not an expert in computer science, finite state automata, or bloc. What will come next is the result of my works on state machines. I present it here to serve as a base to be discussed.
It's also the first time I'm trying to contribute, I'm not used to this process so I hope I'm doing it the correct way.

# Context

This proposal aims to introduce a new class that inherits from `BlocBlase`, in addition to `Cubit` and `Bloc`: `StateMachine`.

Finite state machines are well known in computer science. There are different types of State machines covering different use cases. In this case, the term state machine will refer to a `Mealy Machine`. You can read more about [here](https://en.wikipedia.org/wiki/Mealy_machine).

A Mealy state machine is defined by a set of possible states and a set of possible transitions for each of them. The machine accepts input (UI event) and emits new states (or not) based on its current state and received input.

Where the state machine shines is in its expressiveness, predictability, and robustness:

- It makes it easy to know all possible states of the machine.
- It makes it easy to understand how state transit and what rules apply to these transitions.
- It guaranteed you to never be in an invalid state, which is especially valuable for sensitive parts of the app, like the payment funnel.

It's completely fitting with BLoC philosophy. It's helping you to know what state our application is in at any point in time and it's very predictable.

From app development perspective, State Machine comes with the following benefits:

* The state machine pattern eliminates bugs and weird situations because it won't let the UI transition to a state which we don’t know about.
* The machine is not accepting input which is not explicitly defined as acceptable for the current state. This eliminates the need for code that protects other code from execution.
* It forces the developer to think in a declarative way. This is because we have to define most of the logic upfront. BLoC already does that with events, the state machine pushes it further with states.

In addition to these qualities, State Machine is very close to what BLoC already does, which makes the integration of the state machine in BLoC package straightforward.

Both State Machine and BLoC received events from UI and emit new states based on their current states. The main differences reside in the design of their APIs.

- BLoC doesn't restrict you to a given set of States. You can emit an infinity of different states, as long as there inherit from the base State class. State machines force you to define every possible state at initialization.
- BLoC doesn't restrict you in the transition to a new state. At each event received, you can emit 0 or more new states. With a state machine, you can only emit **1** new State at a time.
- BLoC will react to an event at any time as long a handler has been defined with `on<>()`API. State Machine will **not** react to an event that is not defined for the **current** state.


|                    | BLoC                                | State Machine                                           |
| -------------------| ------------------------------------| --------------------------------------------------------|
| Set of States      | unrestricted                        | defined at initialization                               |
| Set of events      | defined at initialization           | defined at initialization                               |
| New State emission | 0 or more when an event is received | 0 or 1 when an event is received                        |
| Event reaction     | When an event is received           | When an event is received and defined for current state |

To sum up I would say BLoC is more focused on reacting to events while a state machine is focused on transiting inside a graph of states.

To go dive further into the subject, you can look at these great resources. These are javascript's react articles but the concept applies to dart as well. They explain in-depth why state machines are good for app state management.

Blog posts

- [You are managing state? Think twice.](https://krasimirtsonev.com/blog/article/managing-state-in-javascript-with-state-machines-stent)
- [The rise of state machine](https://www.smashingmagazine.com/2018/01/rise-state-machines/)
- [Robust React User Interfaces with Finite State Machines](https://css-tricks.com/robust-react-user-interfaces-with-finite-state-machines/)

Video

- [David Khourshid - Infinitely Better UIs with Finite Automata](https://www.youtube.com/watch?v=VU1NKX6Qkxc)

# Proposal 🚀

Considering the state of flutter state management ecosystem, the great similarity between BLoC and state machine, and the fact that there are already different types of blocs (Cubit and Bloc), I propose to add StateMachine as part of the bloc main package instead of creating a new state management package.

The implementation would be as close as possible to what bloc does to maintain consistency between different APIs.

StateMachine class will inherit from `BlocBase` class, that way it would beneficiated from the great bloc ecosystem (`flutter_bloc`, `bloc_test`, `hydrated_bloc`, `replay_bloc`, etc...).

```dart
abstract class StateMachine<Event, State> extends BlocBase<State>
```

StateMachine would use a builder pattern to easily define its underlying structure. [code_builder](https://pub.dev/packages/code_builder) from [fsm2](https://pub.dev/packages/fsm2) package are good sources of inspiration.

**note about fsm2**

fsm2 looks like a pretty good library for a state machine. It has advanced features like state nesting and visualization. I hadn't based my work on its code because it does not support state's data (an extended state in UML2 spec) but it has been a great source of inspiration.

##### StateMachine definition proposition

I came up with the following assertions:

- State machines can define N different states. All States should inherit from the same super type and should only be defined ones
- States can carry data.
- A state is defined by a list of possible transitions.
- A transition could or couldn't transit to a new state
- Transitions are evaluated sequentially, resulting in that the first transition to transit will emit the next state and subsequent transitions will not be evaluated.

The interface could look like that:

```dart
class TimerStateMachine extends StateMachine<TimerEvent, TimerState> {
  TimerStateMachine({required Ticker ticker})
      : _ticker = ticker,
        super(TimerInitial(_duration)) {
    define<TimerInitial>((b) => b
      ..on<TimerStarted>(
        (event, state) => TimerRunInProgress(event.duration),
      ));

    define<TimerRunInProgress>((b) => b
      ..onEnter((state) => _startTicker(state.duration))
      ..on<TimerTicked>(_onTicked)
      ..on<TimerPaused>(_onPaused)
      ..on<TimerReset>(_onReset));

    define<TimerRunPause>((b) => b
      ..on<TimerResumed>(_onResumed)
      ..on<TimerReset>(_onReset));

    define<TimerRunComplete>(
      (b) => b..on<TimerReset>(_onReset),
    );
  }
```

**Define**

Similar to Bloc's `on<Event>` API, `define<State>` let you define a state. It takes an optional builder at a parameter that gives the user opportunity to define the state's transition and side effects.

```dart
  void define<DefinedState extends State>([StateDefinitionBuilder Function(StateDefinitionBuilder)? definitionBuilder]);
```

`StateDefinitionBuilder` exposes `onEnter` and `onExit` that let users define a side effect that will be triggered when entering or exiting the state.

In addition, onEnter lets you directly change state, more on this in the transition section below.

**Transition**

A transition may or may not return a new state. If a state is returned, it's considered as state machine entering transition. If null is returned from transition, the next transition is evaluated. If all transitions returned null, state stay unchanged.

Transition can be async and will always be awaited before other transitions are evaluated. That way it let the user call an async function to decide if the transition will happen or not, from a repository by example.

A transition is defined using `on<Event>(builder)` API.

```dart
on<DefinedEvent>(
  FutureOr<State?> Function(DefinedEvent, DefinedState) builder,
);
```

In the example above, DefinedEvent is a sub-type of Event and DefinedState is a sub-type of State and it corresponds to the Type defined with `define<DefineState>`

In addition to the event transition, I propose to let `onEnter` be a transition. I called it *immediate transition*. This transition is always evaluated first when entering a state, and it's guaranteed that no event will be processed before the onEnter transition has finished being evaluated.

onEnter transition lets the user change state based on async code without the need to define an event. This is particularly useful for states that depend only on async code to change states.

Take this traffic lights state machine as an example:

```dart
class TrafficLights extends StateMachine<Event, State> {
  TrafficLight() : super(const Red()) {
    define<Green>((b) => b
      ..onEnter(
        (_) => Future.delayed(Duration(seconds: 25), () => Orange()),
      );

    define<Orange>((b) => b
      ..onEnter(
        (_) => Future.delayed(Duration(seconds: 5), () => Red()),
      );

    define<Red>((b) => b
      ..onEnter(
        (_) => Future.delayed(Duration(seconds: 30), () => Green()),
      ));
  }
}
```

It is also useful for initialization, where `Initialized` state is emitted after receiving data from an async func.

onEnter also lets you trigger side effects without changing state, you just need to return null to indicate that state will not change.

# Experimental Implementation

I've made an experimental package to test the feasibility of the concept. You can find it here: [bloc_state_machine_proposal](https://github.com/Pierre2tm/bloc_state_machine_proposal).

It features a working StateMachine that inherits from BlocBase and exposes API described above. you can import find the experimental package inside `/bloc_state_machine_experiment`.

I've also re-implemented the timer example with StateMachine, it can be found under `/example/flutter_timer_state_machine`

Of course, this isn't finished, but I think you could find this interesting and I hope it will contribute to the discussion thanks to a concrete example. Feel free to contribute to this experiment.

**Note about experiment implementation**

I've made two very opinionated choices with transition:

* made them async
* made onEnter a special case transition
  These choices impact underlying architecture and should be discussed, especially onEnter transition. I'm considering splitting onEnter in two, introducing an `immediateTransition` method in the builder, and keeping onEnter a side-effect only like onExit.

Transiting to a newState, where newState == currentState will trigger onEnter and onExit but will not trigger onChange and rebuild UI. This is because I don't override emit method and it's an opinionated design choice. It let self redirecting transition trigger onEnter/onExit side-effects, but I'm not sure having this behavior distinction with onChange is a good idea.

I've skipped transforming events and BlocOverrides in the experiment. I've noticed that BlocOverrides takes a bloc as parameter for onEvent, which makes StateMachine incompatible with it. However, this problem can be addressed by introducing a common superclass for Bloc and State Machine like

```dart
abstract class blocBaseEvent<Event, State> extends BlocBase<State> {}
```

I've also noticed that some tests of flutter_timer_state_machine example didn't pass, it looks like it's coming from `MockTicker`, I'm not able to explain why but I'm suspecting the missing lack of BlocOverride implementation be the cause.

# Additional Features

FSM2 has a nice feature called nested States. Take back our Traffic light example, what if we want to add an On and Off state? Green, Orange, and Red are On states, and adding Off transition in each of them is a lot of boilerplate.
Nested states solve this issue by enabling the following syntax:

```dart
class TrafficLights extends StateMachine<Event, State> {
  TrafficLight() : super(const Red()) {
    define<On>((b) => b
        ..on<TurnOff>((s, e) => Off())
        ..define<Green>((b) => b
          ..onEnter(
            (_) => Future.delayed(Duration(seconds: 25), () => Orange()),
          ));
        ..define<Orange>((b) => b
          ..onEnter(
            (_) => Future.delayed(Duration(seconds: 5), () => Red()),
          ));
        ..define<Red>((b) => b
          ..onEnter(
            (_) => Future.delayed(Duration(seconds: 30), () => Green()),
          ));
    );
    define<Off>((b) => b
      ..on<TurnOn>((e, s) => Red())
    )
  }
}
```

This feature isn't available in the experimental package I've made because I want to get your feedback before investing more time in this, but it's definitely something I want to have.

# Thanks for your attention

Please give this issue a 👍 if you support the proposal or a 👎 if you're against it. If you disagree with the proposal I would appreciate it if you could comment with your reasoning.

Thanks so much for giving attention to this proposal, and let's bring the power of state machines to flutter together! 🙏 🚀