// Author: Naray Puthillathu
module provider_test {
  import provider.* from "./provider"

  run successTest = init
    .then(configure(true, true, true, true))
    .then(launch)
    .then(observe(true, true, true, true, true, true, true, false, false))
    .expect(s.success)

  run disabledTest = init
    .then(configure(false, true, true, true))
    .then(rejectBeforeLaunch)
    .expect(not(s.launched) and not(s.success) and s.coreAvailable)

  run untrustedTest = init
    .then(configure(true, false, true, true))
    .then(rejectBeforeLaunch)
    .expect(not(s.launched) and not(s.success))

  run scopeTest = init
    .then(configure(true, true, false, true))
    .then(rejectBeforeLaunch)
    .expect(not(s.launched) and not(s.success))

  run mutationRequestTest = init
    .then(configure(true, true, true, false))
    .then(rejectBeforeLaunch)
    .expect(not(s.launched) and s.lifeosWrites == 0)

  run incompatibleProviderTest = init
    .then(configure(true, true, true, true))
    .then(launch)
    .then(observe(false, true, true, true, true, true, true, false, false))
    .expect(s.launched and not(s.success))

  run unavailableProviderTest = init
    .then(configure(true, true, true, true))
    .then(launch)
    .then(observe(true, false, false, false, false, false, false, false, false))
    .expect(s.launched and not(s.success) and s.coreAvailable)

  run malformedSuccessTest = init
    .then(configure(true, true, true, true))
    .then(launch)
    .then(observe(true, true, true, true, false, true, true, false, false))
    .expect(s.launched and s.providerSuccess and not(s.success))

  run wrongScopeSuccessTest = init
    .then(configure(true, true, true, true))
    .then(launch)
    .then(observe(true, true, true, true, true, false, true, false, false))
    .expect(not(s.success))

  run wrongDigestSuccessTest = init
    .then(configure(true, true, true, true))
    .then(launch)
    .then(observe(true, true, true, true, true, true, false, false, false))
    .expect(not(s.success))

  run providerMutationTest = init
    .then(configure(true, true, true, true))
    .then(launch)
    .then(observe(true, true, true, true, true, true, true, true, false))
    .expect(not(s.success) and s.lifeosWrites == 0)

  run attemptedCoreImpactTest = init
    .then(configure(true, true, true, true))
    .then(launch)
    .then(observe(true, true, true, false, true, true, true, false, true))
    .expect(not(s.success) and s.coreAvailable)
}
