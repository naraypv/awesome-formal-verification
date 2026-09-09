// Author: Naray Puthillathu
// Deliberately broken acceptance logic used only to prove the invariant is
// capable of finding a bad implementation. CI requires verification to fail.
module provider_mutant {
  type State = {
    phase: str,
    configured: bool,
    trusted: bool,
    scopeOk: bool,
    readOnlyRequest: bool,
    launched: bool,
    compatible: bool,
    available: bool,
    providerReturned: bool,
    providerSuccess: bool,
    responseValid: bool,
    responseScopeOk: bool,
    responseDigestOk: bool,
    providerMutationObserved: bool,
    success: bool,
    coreAvailable: bool,
    lifeosWrites: int,
  }
  var s: State
  action init = s' = {
    phase: "new", configured: false, trusted: false, scopeOk: false,
    readOnlyRequest: true, launched: false, compatible: false,
    available: false, providerReturned: false, providerSuccess: false,
    responseValid: false, responseScopeOk: false, responseDigestOk: false,
    providerMutationObserved: false, success: false, coreAvailable: true,
    lifeosWrites: 0,
  }
  pure def mayLaunch(x: State): bool =
    x.configured and x.trusted and x.scopeOk and x.readOnlyRequest
  pure def acceptableOutcome(x: State): bool =
    x.launched and x.compatible and x.available and x.providerReturned and
    x.providerSuccess and x.responseValid and x.responseScopeOk and
    x.responseDigestOk and not(x.providerMutationObserved)
  action step = any {
    all {
      s.phase == "new",
      s' = {...s, phase: "awaiting", configured: true, trusted: true,
        scopeOk: true, readOnlyRequest: true, launched: true},
    },
    all {
      s.phase == "awaiting",
      // BUG: accept a provider's success flag despite incompatible, malformed,
      // wrong-scope, wrong-digest and mutation observations.
      s' = {...s, phase: "done", compatible: false, available: true,
        providerReturned: true, providerSuccess: true, responseValid: false,
        responseScopeOk: false, responseDigestOk: false,
        providerMutationObserved: true, success: true},
    },
    all { s.phase == "done", s' = s },
  }
  val invariant =
    (s.success implies mayLaunch(s)) and
    (s.success implies acceptableOutcome(s)) and
    (s.launched implies mayLaunch(s)) and
    ((not(s.compatible) or not(s.available) or not(s.providerReturned) or
      not(s.providerSuccess) or not(s.responseValid) or not(s.responseScopeOk) or
      not(s.responseDigestOk) or s.providerMutationObserved) implies not(s.success)) and
    s.coreAvailable and s.lifeosWrites == 0
}
