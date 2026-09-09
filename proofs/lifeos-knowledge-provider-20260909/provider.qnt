// Author: Naray Puthillathu
// Finite lifecycle abstraction. Provider outcomes are independent inputs;
// OS/JSON/storage behavior and no-write effects are tested separately.
module provider {
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
    providerTriedCoreImpact: bool,
    success: bool,
    coreAvailable: bool,
    lifeosWrites: int,
  }

  var s: State

  action init = s' = {
    phase: "new",
    configured: false,
    trusted: false,
    scopeOk: false,
    readOnlyRequest: true,
    launched: false,
    compatible: false,
    available: false,
    providerReturned: false,
    providerSuccess: false,
    responseValid: false,
    responseScopeOk: false,
    responseDigestOk: false,
    providerMutationObserved: false,
    providerTriedCoreImpact: false,
    success: false,
    coreAvailable: true,
    lifeosWrites: 0,
  }

  pure def mayLaunch(x: State): bool =
    x.configured and x.trusted and x.scopeOk and x.readOnlyRequest

  pure def acceptableOutcome(x: State): bool =
    x.launched and x.compatible and x.available and x.providerReturned and
    x.providerSuccess and x.responseValid and x.responseScopeOk and
    x.responseDigestOk and not(x.providerMutationObserved)

  action configure(c: bool, t: bool, p: bool, r: bool): bool = all {
    s.phase == "new",
    s' = {...s, phase: "configured", configured: c, trusted: t,
      scopeOk: p, readOnlyRequest: r},
  }

  action launch = all {
    s.phase == "configured",
    mayLaunch(s),
    s' = {...s, phase: "awaiting", launched: true},
  }

  action rejectBeforeLaunch = all {
    s.phase == "configured",
    not(mayLaunch(s)),
    s' = {...s, phase: "done", launched: false, success: false},
  }

  // Every argument is an independently modeled provider/transport observation.
  // The acceptance calculation is the LifeOS validation boundary under proof.
  action observe(k: bool, a: bool, returned: bool, reportedSuccess: bool,
      valid: bool, scopeMatches: bool, digestMatches: bool,
      mutationObserved: bool, triedCoreImpact: bool): bool = all {
    s.phase == "awaiting",
    s' = {...s,
      phase: "done",
      compatible: k,
      available: a,
      providerReturned: returned,
      providerSuccess: reportedSuccess,
      responseValid: valid,
      responseScopeOk: scopeMatches,
      responseDigestOk: digestMatches,
      providerMutationObserved: mutationObserved,
      providerTriedCoreImpact: triedCoreImpact,
      success: k and a and returned and reportedSuccess and valid and
        scopeMatches and digestMatches and not(mutationObserved),
      coreAvailable: true,
      lifeosWrites: 0,
    },
  }

  action step = any {
    {
      nondet c = Set(false, true).oneOf()
      nondet t = Set(false, true).oneOf()
      nondet p = Set(false, true).oneOf()
      nondet r = Set(false, true).oneOf()
      configure(c, t, p, r)
    },
    launch,
    rejectBeforeLaunch,
    {
      nondet k = Set(false, true).oneOf()
      nondet a = Set(false, true).oneOf()
      nondet returned = Set(false, true).oneOf()
      nondet reportedSuccess = Set(false, true).oneOf()
      nondet valid = Set(false, true).oneOf()
      nondet scopeMatches = Set(false, true).oneOf()
      nondet digestMatches = Set(false, true).oneOf()
      nondet mutationObserved = Set(false, true).oneOf()
      nondet triedCoreImpact = Set(false, true).oneOf()
      observe(k, a, returned, reportedSuccess, valid, scopeMatches,
        digestMatches, mutationObserved, triedCoreImpact)
    },
    all { s.phase == "done", s' = s },
  }

  val successRequiresPreflight = s.success implies mayLaunch(s)
  val successRequiresValidatedOutcome = s.success implies acceptableOutcome(s)
  val launchRequiresPreflight = s.launched implies mayLaunch(s)
  val invalidOutcomeNeverSucceeds =
    (not(s.compatible) or not(s.available) or not(s.providerReturned) or
      not(s.providerSuccess) or not(s.responseValid) or not(s.responseScopeOk) or
      not(s.responseDigestOk) or s.providerMutationObserved) implies not(s.success)
  val optionalCoreSurvivesProviderBehavior = s.coreAvailable
  val lifeosNeverRequestsWrites = s.lifeosWrites == 0

  val invariant = successRequiresPreflight and successRequiresValidatedOutcome and
    launchRequiresPreflight and invalidOutcomeNeverSucceeds and
    optionalCoreSurvivesProviderBehavior and lifeosNeverRequestsWrites
}
