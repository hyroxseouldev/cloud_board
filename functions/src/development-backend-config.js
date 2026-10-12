export const developmentProject = 'cloud-board-development';
export const developmentFunctionCodebase = 'account-deletion';
export const developmentOnboardingSecret = 'CLOUDBOARD_DEVELOPMENT_ONBOARDING_SECRET';

// An explicit deploy boundary: no AI provider, SMS provider, store receipt or
// billing notification endpoints are provisioned in the isolated project.
export const developmentFunctionNames = Object.freeze([
  'deleteMyAccount', 'retryAccountDeletions', 'syncWorkoutCatalog',
  'syncLegacyWorkoutSettings', 'cleanupPlaybackSnapshots', 'updateSlideLibrary',
  'syncSlideLibraryPlan', 'cloudboardAppOnboarding', 'syncAppTrialAccess',
  'cleanupOnboardingVerification', 'reportClientDiagnostic', 'listLibraryFolders',
  'manageLibraryFolder', 'cleanupClientDiagnostics',
]);

export function onboardingSecretBindings(projectId) {
  return projectId === developmentProject ? [developmentOnboardingSecret]
    : ['CLOUDBOARD_ONBOARDING_SECRET', 'SOLAPI_API_KEY', 'SOLAPI_API_SECRET'];
}

export function developmentDeployTargets(projectId) {
  if (projectId !== developmentProject) throw new Error('Explicit development project required');
  return developmentFunctionNames.map(name => `functions:${developmentFunctionCodebase}:${name}`).join(',');
}
