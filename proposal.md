Hello everyone! 👋

Thanks you for the amzing job done with BLoC and I hope you will find this proposal intersesting.

🚧Disclamer🚧

I'm not an expert in computer science, finite state automata or bloc. What will come next is the result of my works about state machines. I present it here to serve as a base to be discussed.

# Context

This proposal aims to introduce a new class that inherit from `BlocBlase`, in addition to `Cubit` and `Bloc`: `StateMachine`.

Finite state machines are well know in computer science. There are differents types of State machines covering differents use cases. In this case, the term state machine will refere to a `Mealy Machine`.

A Mealy state machine is defined by a set of possible states and set of possible transitions for each of them. The machine accept input (UI event) and emit newState (or not) based on it's current state and received input.

Where State machine really shine is in it's expressivness, predictability and robustness:

- Its makes easy to know all possible State of the machine
- Its make esay to understand how state transite and what rules apply to this transitions
- It guaranteed you to never be in invalid state, witch is unvaluable

It's completly fiting with BLoC phylosophie. Its helping you to know what state our application is in at any point in time and it's very predictable.

From UI percpective, State Machine comes with the following benefits:

* The state machine pattern eliminates bugs and weird situations because it
  wont let the UI transition to state which we don’t know about.
* The machine is not accepting input which is not explicitly defined as
  acceptable for the current state. This eliminates the need of code that
  protects other code from execution.
* It forces the developer to think in a declarative way. This is because we
  have to define most of the logic upfront

In addition to this qualities, State Machine is realy clause to what BLoC already does. Witch make the intergation of state machine in bloc package really straightforward.

Both State Machine and BLoC received events from UI and emit new states based on there current states. The main differences reside in the design of there APIs.

- BLoC does't restrict the you to a given set of States. You can emit an ininity of differents states, as long as there inherits from the base State Class. State machine force you to define every possible states at initialization
- BLoC doesn't restrict you in the transition to new state. At each event received, you can emit 0 or more new states. With a State Machine, you can only emit **1** new State at time.
- BLoC will react to an event at anytime as long a handler has been defined with `on<>()`API. State Machine will **not** react to event that are not defined for the **current** state.


|                    | BLoC                                | State Machine                                        |
| -------------------- | ------------------------------------- | ------------------------------------------------------ |
| Set of States      | unrestricted                        | defined at initialization                            |
| New State emittion | 0 or more when an event is recieved | 0 or 1 when an event is recieved                     |
| Event reaction     | When event is recieved              | When event is recieved and defined for current state |

To sum up I would say BLoC is more focus on reacting to event while State machine is focus on transiting inside a graph of states.

To go dive further the subject, you can look at theeses greats ressources. Theses are javacript's react articles but the concept apply to dart as well. They explaining in-depth why state machine are good for app state management.

Blog posts

- [You are managing state? Think twice.](https://krasimirtsonev.com/blog/article/managing-state-in-javascript-with-state-machines-stent)
- [The rise of state machine](https://www.smashingmagazine.com/2018/01/rise-state-machines/)
- [Robust React User Interfaces with Finite State Machines](https://css-tricks.com/robust-react-user-interfaces-with-finite-state-machines/)

Video

- [David Khourshid - Infinitely Better UIs with Finite Automata](https://www.youtube.com/watch?v=VU1NKX6Qkxc)

# Proposal 🚀

Considering the state of flutter state management ecosystem, the great similarity between block and state machine and the fact that there are allready diffents types of blocs (Cubit and Bloc), I propose to add StateMachine as part of the bloc main package instead of creating a new state management package.

The implementation would be as close as possible to what bloc do to maintain concistency bettween differents APIs.

StateMachine class will inherit from `BlocBase` class, that way it would beneficiated from the great bloc ecosytem (`flutter_bloc`, `bloc_test`, `hydrated_bloc`, `replay_bloc`, etc...).

```dart
abstract class StateMachine<Event, State> extends BlocBase<State>
```

StateMachine would use a builder pattern to easly define it's underling structure. [code_builder](https://pub.dev/packages/code_builder) from [fsm2](https://pub.dev/packages/fsm2) package are great source of inspiration.

**note about fsm2**

fsm2 looks like a pretty good library for state machine. It has advanced features like state nesting and visualization. I hadn't based my work on it's code because it does not support state's data (exended state in UML2 spec) but it's definitly a great source of inspiration.

##### StateMachine definition proposition

I came with the following assertions:

- State machine can define N differents state. All States should inherit from a same super type and should only be defined ones
- States can carry data.
- A State is defined by a list of possible transitions.
- A transition could or couln't transit to a new state
- Transitions are evaluated sequentialy, resuling that the first transition to transit will emit the next state and sub-sequent transitions will not be evaluated.

The interface could looks like that:

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

Similare to Bloc's `on<Event>` API, `define<State>` let you define a state. It's take an optional builder at parameter that give user oportunity to define state's transition and side effects.

```dart
  void define<DefinedState extends State>([StateDefinitionBuilder Function(StateDefinitionBuilder)? definitionBuilder]);
```

`StateDefinitionBuilder` expose `onEnter` and `onExit` that let user define sideEffect that will be triggered when entering or exiting the state.

In addition, onEnter let you directly change state, more on this in transition section bellow.

**Transition**

A tranistion may or may not return a new state. If a state is returned, it his considered as state machine entering transition. No other transition will be evaluated until next state has been emitted. If null is returned from transition, next transition is evaluated.

Transition can be async and will allways be awaited before others transitions are evaluated. That way it let user call async function to decide if transition will happen or not, from repository by example.

A transition is defined using `on<Event>(builder)` API.

```dart
on<DefinedEvent>(
  FutureOr<State?> Function(DefinedEvent, DefinedState) builder,
);
```

In the example above, DefinedEvent is a sub-type of Event and DefinedState is a sub-type of State and it corespond to the Type defined with `define<DefineState>`

In addition to the event transition, I propose to add let `onEnter` be transition. I called it *immediate transition*. This transition is allways evaluated first when entering a state, and its garanted that no event will be proccessed before the onEnter transition has finished being evaluated.

onEnter transition let you change state based on async code without the need to define an event. This is particularly useful for states that depend only on async codde to change states.

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

It can also be used as a 'redirection guard', where a condition is evaluated on entering state and can redirect to another state.

onEnter is a also a good place to trigger side effect, you just need to not return null to inidicate that state will not change.

### Experimental Implementation

I've made an experimental package to test the feasability of the concept. You can find it here: [bloc_state_machine_proposal](https://github.com/Pierre2tm/bloc_state_machine_proposal).

It's feature a working StateMachine that inherit form BlocBase and expose API decrived above. you can import find the expiremental package inside `/bloc_state_machine_experiment`.

I've also re-implemented timer example with StateMachine, it can be found under `/example/flutter_timer_state_machine`

Of course this isn't finished, but I think you could find this interesting and I hope it will contribute to the discussion thanks to concrete example. Feel help improving this project.

**Note about implementation**

I've made two very opinionated choice with transition:

* made them async
* made onEnter a special case transition

Theses choices impact underling architecture and should discuted, espicially onEnter transition. I'm actually considering splitting onEnter in two, introducting an immediateTransition method in builder and keep onEnter a sideEffect only like onExit.

Transiting to a newState, where newState == currentState will trigger onEnter and onExit but will not trigger onChange and rebuild UI. This is because I don't override emit method and it's an opinionated design choice. It let self redirecting immediate transition works but i'm not 100% sure about that.

I've totally skiped transforming event and BlocOverrides in the experiment. I've noticied that BlocOverrides takes a bloc as parameter for onEvent, whitch makes StateMachine incomatible with it. However this problem can be addressed by introducing a common super class for Bloc and State Machine like

```dart

abstract class blocBaseEvent<Event, State> exends BlocBase<State> {}
```

I've also noticied that some tests of flutter_timer_state_machine exmple did't pass, its looks like it's comming from `MockTicker`, I'm not able to explain why but I'm suspecting the missing lack of BlocOverride implentation be the cause.

### Additional Features

FSM2 have a nice feature called Nested States. Take back our Traffic light exmaple, what if we want to add an On and Off State ? Nested States solve this issue by enabling following syntax:

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

This feature isn't available in the experimental package I've made because I want see your feedbacks before investing more time on this, but its definitly something i want to add.

### Thanks for your attention

Please give this issue a 👍 if you support the proposal or a 👎 if you're against it. If you disagree with the proposal I would really appreciate it if you could comment with your reasoning.

Thanks so much for attention to this proposal, and let's bring the power of state machines to flutter together! 🙏🚀
