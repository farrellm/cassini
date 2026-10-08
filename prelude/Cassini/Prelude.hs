-- | The project prelude: @relude@, minus the names that collide with
-- @effectful@ or with this project's vocabulary (DESIGN.md §2.3).
--
-- Every stanza that consumes it renames it to @Prelude@ through cabal
-- @mixins@, so no module imports it by name.
module Cassini.Prelude (module Relude) where

-- The subtraction, by reason. Ormolu sorts the import list, so the grouping
-- lives here:
--
-- - Collides name-for-name with Effectful.State.Static.Local: State, get, put,
--   modify, gets, state, evalState, execState, runState.
-- - Collides name-for-name with Effectful.Reader.Static: Reader, ask, asks,
--   local, runReader, withReader (effectful's withReader is a reinterpreter,
--   not mtl's).
-- - No effectful counterpart, but the kernel has no transformer stack (§4.3),
--   so a module that wants one says so in its own import list: StateT,
--   MonadState, modify', evalStateT, execStateT, runStateT, ReaderT,
--   MonadReader, runReaderT.
-- - Collides with this project's vocabulary: one (Relude.Container.One's
--   singleton; we want the ring constant), Undefined (Relude.Debug's marker
--   type; we want Cohen's Undefined, §4.6).
import Relude hiding
  ( MonadReader,
    MonadState,
    Reader,
    ReaderT,
    State,
    StateT,
    Undefined,
    ask,
    asks,
    evalState,
    evalStateT,
    execState,
    execStateT,
    get,
    gets,
    local,
    modify,
    modify',
    one,
    put,
    runReader,
    runReaderT,
    runState,
    runStateT,
    state,
    withReader,
  )
