import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

/// Signature of a function that may or may not emit a new state
/// based on it's current state
typedef StateBuilder<SuperState, CurrentState extends SuperState>
    = FutureOr<SuperState?> Function(CurrentState);

/// Signature of a function that may or may not emit a new state
/// base on it's current state an an external event
typedef EventStateBuilder<Event, SuperState, CurrentState extends SuperState>
    = FutureOr<SuperState?> Function(Event, CurrentState);

/// Signature of a callback function called by the state machine
/// in various contexts that hasn't the ability to emit new state
typedef SideEffect<CurrentState> = FutureOr<void> Function(CurrentState);

/// An event handler for a given [DefinedState]
/// created using on<Event>() api
class _StateEventHandler<SuperEvent, SuperState,
    DefinedEvent extends SuperEvent, DefinedState extends SuperState> {
  const _StateEventHandler({
    required this.isType,
    required this.type,
    required this.builder,
    // this.transformer,
  });
  final bool Function(dynamic value) isType;
  final Type type;

  final EventStateBuilder<DefinedEvent, SuperState, DefinedState> builder;
  // final EventTransformer<SuperEvent>? transformer;

  FutureOr<SuperState?> handle(SuperEvent e, SuperState s) async =>
      builder(e as DefinedEvent, s as DefinedState);
}

/// Definition of a state
/// This class is intended to be constructed using
/// [StateDefinitionBuilder]
class _StateDefinition<Event, SuperState, DefinedState extends SuperState> {
  const _StateDefinition(
    this._handlers, {
    this.onEnter,
    this.onExit,
  });

  const _StateDefinition.empty()
      : _handlers = const [],
        onEnter = null,
        onExit = null;

  final StateBuilder<SuperState, DefinedState>? onEnter;
  final SideEffect<DefinedState>? onExit;
  final List<_StateEventHandler> _handlers;

  FutureOr<SuperState?> enter(DefinedState state) => onEnter?.call(state);
  FutureOr<void> exit(DefinedState state) => onExit?.call(state);

  FutureOr<SuperState?> add(
    Event event,
    SuperState state,
  ) async {
    final stateHandlers = _handlers.where(
      (handler) => handler.isType(event),
    );
    for (final handler in stateHandlers) {
      final nextState = (await handler.handle(event, state)) as SuperState?;
      if (nextState != null) return nextState;
    }
    return null;
  }
}

/// A builder that let's define a state transitions
///
/// * [onEnter] let you register a [StateBuilder] that is called immediately
/// after state machine enter in [DefinedState]. If [StateBuilder] emit
/// a new state, state machine will transit to that state.
/// State machine will wait for onEnter Completion in order to evaluate
/// any event received, meaning that you are guaranteed that [onEnter]
/// transition will always be evaluated before [on] transition and [onExit]
///
/// * [on] let you register an additional event handler for [DefinedState].
/// You can have multiple [on] transition of the same [Event] type.
/// [on] transitions are evaluated sequentially, meaning if two or more
/// [on] transitions could transit to a new [State] only the first declared one
/// will be evaluated an therefore emit a new state.
///
/// * [onExit] let you register a [SideEffect] callback that will be called when
/// the state machine leave [DefinedState]
class StateDefinitionBuilder<Event, State, DefinedState extends State> {
  final List<_StateEventHandler> _handlers = [];
  StateBuilder<State, DefinedState>? _onEnter;
  SideEffect<DefinedState>? _onExit;

  /// Let you register a [StateBuilder] that is called immediately
  /// after state machine enter in [DefinedState].
  ///
  /// If [StateBuilder] emit
  /// a new state, state machine will transit to that state.
  /// State machine will wait for onEnter Completion in order to evaluate
  /// any event received, meaning that you are guaranteed that [onEnter]
  /// transition will always be evaluated before [on] transition and [onExit]
  void onEnter(StateBuilder<State, DefinedState> sideEffect) {
    assert(() {
      if (_onEnter != null) {
        throw StateError(
          'onEnter was called multiple times.'
          'There should only be a single onEnter handler per state.',
        );
      }
      return true;
    }());
    _onEnter = sideEffect;
  }

  /// Let you register a [SideEffect] callback that will be called when
  /// the state machine leave [DefinedState].
  void onExit(SideEffect<DefinedState> sideEffect) {
    assert(() {
      if (_onExit != null) {
        throw StateError(
          'onExit was called multiple times.'
          'There should only be a single onExit handler per state.',
        );
      }
      return true;
    }());
    _onExit = sideEffect;
  }

  /// [on] let you register an additional event handler for [DefinedState].
  ///
  /// You can have multiple [on] transition of the same [Event] type.
  /// [on] transitions are evaluated sequentially, meaning if two or more
  /// [on] transitions could transit to a new [State] only the first declared one
  /// will be evaluated an therefore emit a new state.
  void on<DefinedEvent extends Event>(
          EventStateBuilder<DefinedEvent, State, DefinedState> builder
          //    {
          //   EventTransformer<DefinedEvent>? transformer,
          // }
          ) =>
      _handlers.add(
        _StateEventHandler<Event, State, DefinedEvent, DefinedState>(
          builder: builder,
          isType: (dynamic e) => e is DefinedEvent,
          type: DefinedEvent,
        ),
      );

  _StateDefinition<Event, State, DefinedState> _build() => _StateDefinition(
        _handlers,
        onEnter: _onEnter,
        onExit: _onExit,
      );
}

abstract class StateMachine<Event, State> extends BlocBase<State>
    implements BlocEventSink<Event> {
  StateMachine(State initial) : super(initial) {
    _bindInternalStateStream();
    _bindEventsToStates();
    _stateMachineController.add(initial);
  }

  // final _blocObserver = BlocOverrides.current?.blocObserver;
  final _stateMachineController = StreamController<State>();
  final _stateDefinitions = <Type, _StateDefinition>{};
  final _eventController = StreamController<Event>();
  late final StreamSubscription? _stateMachineSubscription;
  late final StreamSubscription? _eventSubscription;

  @override
  void add(Event event) {
    // TODO: CHECK IF HANLDER/STATE EXIST
    try {
      onEvent(event);
      _eventController.add(event);
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      rethrow;
    }
  }

  void define<DefinedState extends State>([
    StateDefinitionBuilder<Event, State, DefinedState> Function(
      StateDefinitionBuilder<Event, State, DefinedState>,
    )?
        definitionBuilder,
  ]) {
    // TODO: CHECK IF HANLDER/STATE EXIST
    _stateDefinitions.putIfAbsent(DefinedState, () {
      if (definitionBuilder != null) {
        return definitionBuilder
            .call(StateDefinitionBuilder<Event, State, DefinedState>())
            ._build();
      } else {
        return _StateDefinition<Event, State, DefinedState>.empty();
      }
    });
  }

  @protected
  @mustCallSuper
  void onEvent(Event event) {
    // TODO: StateMachineObserver
    // ignore: invalid_use_of_protected_member
    // _blocObserver?.onEvent(this, event);
  }

  /// Maybe exposing emit its not a good idea ?
  /// State should be added via _stateMachineController.add(state)
  /// Otherwise it will not trigger onEnter/onExit
  @protected
  @visibleForTesting
  @override
  void emit(State state) => super.emit(state);

  void _bindEventsToStates() {
    //Todo: add transformer
    _eventSubscription = _eventController.stream.asyncMap<State?>(
      (event) async {
        return (await _currentStateDefinition.add(event, state)) as State?;
      },
    ).listen((State? maybeState) {
      if (maybeState != null) {
        _stateMachineController.add(maybeState);
      }
    });
  }

  /// Listen to [_stateMachineController] to [emit] new State
  /// and trigger onEnter, onExit callback
  /// onEnter is awaited and if it emit a new state (immediate transition),
  /// emitted state is added to [_stateMachineController]'s stream.
  /// While processing of newState and until onEnter return null,
  /// Event processing are disabled using [_eventSubscription]'s pause method
  void _bindInternalStateStream() {
    _stateMachineSubscription =
        _stateMachineController.stream.asyncMap((newState) async {
      _eventSubscription?.pause();
      _currentStateDefinition.exit(state);
      emit(newState);
      final immediateStateTransition = (await _currentStateDefinition.enter(
        newState,
      )) as State?;
      if (immediateStateTransition != null) {
        _stateMachineController.add(immediateStateTransition);
      } else {
        _eventSubscription?.resume();
      }
    }).listen(null);
  }

  // Closes the `event` and `state` `Streams`.
  // This method should be called when a [Bloc] is no longer needed.
  // Once [close] is called, `events` that are [add]ed will not be
  // processed.
  // In addition, if [close] is called while `events` are still being
  // processed, the [Bloc] will finish processing the pending `events`.
  @mustCallSuper
  @override
  Future<void> close() async {
    await _eventSubscription?.cancel();
    await _stateMachineSubscription?.cancel();
    await _eventController.close();
    await _stateMachineController.close();
    return super.close();
  }

  //TODO: error if no hanlder exist
  _StateDefinition get _currentStateDefinition =>
      _stateDefinitions[state.runtimeType]!;
}
