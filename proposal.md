Hello everyone! 👋

Thanks you for the amzing job done with BLoC ! I've started using the package few month ago, in my quest for creating app with reliable and beautifull code and i really loved it.

I hope this proposal will interest you. I'm trully convainced that states machine should have a great place in app developpment

🚧Disclamer🚧

I'm not an expert in computer science, finite state automata or bloc. What will come next is the result of my works about state machines and how I thinks it should be done. I present it here to serve as a base to be discussed. I don't claim to be right in thinking that state machines should be added to the block package nor how they should be implemented.

# Context

This proposal aims to introduce a new class that inherit from `BlocBlase`, in addition to `Cubit` and `Bloc`: `StateMachine`.

Finite state machines are allrady well know in computer science. There are differents type of State machines covering differents use cases. Here the term state machine will refere to a `Mealy Machine`.

A Mealy state machine is defined by a set of possible states and set of possible transitions for each of them. The machine accept input (UI event) and emit newState (or not) based on it's current state and received input.

From UI percpective, State Machine comes with the following benefits:

* The state machine pattern eliminates bugs and weird situations because it
  wont let the UI transition to state which we don’t know about.
* The machine is not accepting input which is not explicitly defined as
  acceptable for the current state. This eliminates the need of code that
  protects other code from execution.
* It forces the developer to think in a declarative way. This is because we
  have to define most of the logic upfront.

I won't argue further in favor of state machine and instead links you to theeses following ressources that are allready covering this topic in-depth, they do it better than me (In fact I've copy/past some of there argument in the paragraph above). Theses are javacript's react articles but the concept apply to dart as well.

Blog posts

- [You are managing state? Think twice.](https://krasimirtsonev.com/blog/article/managing-state-in-javascript-with-state-machines-stent)
- [The rise of state machine](https://www.smashingmagazine.com/2018/01/rise-state-machines/)
- [Robust React User Interfaces with Finite State Machines](https://css-tricks.com/robust-react-user-interfaces-with-finite-state-machines/)

Video

- [David Khourshid - Infinitely Better UIs with Finite Automata](https://www.youtube.com/watch?v=VU1NKX6Qkxc)

**Similarities bettween BLoC and state machine**

You have problably noticved in the explanation above that State Machine is realy clause to BLoC in what it does. Both received events from UI and emit new states based on there current states.

There are differences bettwen a BLoC and a State Machine:

- BLoC does't restrict the you to a given set of States. You can emit an ininity of differents states, as long as there inherit from the base State Class. The State machine force you to define every possible states at initialization
- BLoC doesn't restrict you in the transition to new state. At each event received, you can emit 0 or more new states. With a State Machine, you can only emit **1** new State at time.
- BLoC will react to an event at anytime as long a handler has been defined with `on<>()`API. State Machine will **not** react to event that are not defined for the **current** state.

To sum up I would say BLoC is more focus on reacting to event while State machine is focus on transiting inside a graph of states.

# Proposal 🚀

Considering the state of flutter state management ecosystem, the great similarity between block and state machine and the fact that there are allready diffents types of blocs (Cubit and Bloc), I propose to add StateMachine as part of the bloc main package.

The implementation would be as close as possible to what bloc do to maintain concistency bettween differents APIs.

StateMachine class will inherit from `BlocBase` class, that way it would beneficiated from the great bloc ecosytem (`flutter_bloc`, `bloc_test`, `hydrated_bloc`, `replay_bloc`, etc...).

```dart
abstract class StateMachine<Event, State> extends BlocBase<State>
```

StateMachine would use a builder pattern to easly define it's underling structure. [code_builder](https://pub.dev/packages/code_builder) from [fsm2](https://pub.dev/packages/fsm2) package are great source of inspiration.

**note about fsm2**

fsm2 looks like a pretty good library for state machine. It has advanced features like nesting, state machine export and visualization. I hadn't based my work on it's code because it does not support state's data (exended state in UML2 spec). However you will see that the interface I propose is similare.

##### StateMachine definition proposition

🚧 Implementation is highly subjectiv and need to be discussed 🚧

I came with the following assertion:

- State machine define N differents state. All States should inherit from a same super type and should only be defined ones
- States can carry data.
- A State is defined by a list of possible transitions.
- A transition could or couln't transit to a new state
- Transitions are evaluated sequentialy, resuling that the first transition to transit will emit the next state and sub-sequent transitions will not be evaluated.

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

Similare to Bloc's `on<Event>` API, `define<State>` let you define a state. It's take an optional builder at parameter that give user oportunity to define state's transition.

```dart
  void define<DefinedState extends State>([StateDefinitionBuilder Function(StateDefinitionBuilder)? definitionBuilder]);
```

**Transition**

A tranistion may or may not return a new state. If a state is returned, it his considered as state machine entering transition. No other transition will be evaluated until next state has been emitted. If null is returned from transition, next transition is evaluated.

Transition can be async and will allways be awaited before others transitions are evaluated.

A transition is defined using `on<Event>(builder)` API.

```dart
on<DefinedEvent>(
  FutureOr<State?> Function(DefinedEvent, DefinedState) builder,
);
```

In the example above, DefinedEvent is a sub-type of Event and DefinedState is a sub-type of State and it corespond to the Type defined with `define<DefineState>`

In addition to the event transition, I propose to add the `onEnter` transition, or *immediate transition*. This transition is allways evaluated first when entering a state, and its garanted that no event will be proccessed before the onEnter transition has finished being evaluated.

Its particularly handy when state transition depends on a timer. Thanks to onEnter you'r not obligated to add onTimerEnd event and thats save a lot of boiler plate code for this use case. It also a good place to trigger side effect, even if you don't update state.

This Traffic lights example illustrate this point:

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

### Experimental PR

I've made an experimental PR to test the feasability of the concept. You can find it here: [pr](link).

It's feature a working StateMachine ans StateDefinitionBuilder classes that enable syntax decrived above.

I've also re-implmented timer example with StateMachine, it can be found under `/example/flutter_timer_state_machine`

This wrok is highly experimental !

**Note about implementation**

Transiting to a newState, where newState == currentState will trigger onEnter and onExit but will not trigger onChange and rebuild UI.

BlocOverrides is not compatible with StateMachine since StateMachine is of type BlocBase. I don't know if a StateMachineOverrides should be introduce. I've skipped this part in the PR.

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

This feature isn't available in the experimental PR I've made because I want your feedback before investing more time on this, but it definitly a must have and it's tottaly feasable.

### Thanks for your attention

Please give this issue a 👍 if you support the proposal or a 👎 if you're against it. If you disagree with the proposal I would really appreciate it if you could comment with your reasoning.

Thanks so much for all of the continued support and looking forward to hearing everyone's thoughts on the proposal! 🙏
