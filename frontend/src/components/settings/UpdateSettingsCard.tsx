import { useEffect } from 'react';
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter, Button } from '../ui';
import { Download, RefreshCw, Check, ExternalLink, Info, X } from 'lucide-react';
import { useUpdateStore } from '../../stores/updateStore';

export const UpdateSettingsCard = () => {
  const {
    updateInfo,
    isLoading,
    error,
    lastChecked,
    dismissed,
    checkForUpdates,
    resetDismiss,
    clearError,
  } = useUpdateStore();

  // Detect platform
  const isWindows = navigator.platform.toLowerCase().includes('win');
  const platform = isWindows ? 'windows' : 'linux';

  useEffect(() => {
    // Load update info on mount
    checkForUpdates();
  }, [checkForUpdates]);

  const currentScript = updateInfo?.scripts?.[platform];

  return (
    <Card id="updates">
      <CardHeader>
        <div className="flex items-center justify-between flex-wrap gap-2">
          <div>
            <CardTitle className="flex items-center gap-2">
              <Download size={20} />
              Software Updates
            </CardTitle>
            <CardDescription>
              Check for and install updates to Hytale Server Manager
            </CardDescription>
          </div>
          {updateInfo?.updateAvailable && !dismissed && (
            <span className="flex items-center gap-1 px-2 py-1 bg-accent-primary/20 text-accent-primary rounded text-sm">
              <Download size={14} />
              Update Available
            </span>
          )}
        </div>
      </CardHeader>
      <CardContent>
        {error && (
          <div className="bg-red-500/10 text-red-500 p-3 rounded mb-4 flex items-center justify-between">
            <span>{error}</span>
            <button onClick={clearError} className="hover:opacity-80">
              <X size={16} />
            </button>
          </div>
        )}

        {/* Version Info */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
          <div className="p-4 bg-gray-100 dark:bg-gray-800 rounded-lg">
            <p className="text-sm text-text-light-muted dark:text-text-muted mb-1">Current Version</p>
            <p className="text-lg font-semibold text-text-light-primary dark:text-text-primary">
              v{updateInfo?.currentVersion || '...'}
            </p>
          </div>
          <div className="p-4 bg-gray-100 dark:bg-gray-800 rounded-lg">
            <p className="text-sm text-text-light-muted dark:text-text-muted mb-1">Latest Version</p>
            <p className="text-lg font-semibold text-text-light-primary dark:text-text-primary">
              {updateInfo?.latestVersion ? `v${updateInfo.latestVersion}` : isLoading ? 'Checking...' : 'Unknown'}
            </p>
          </div>
        </div>

        {/* Update Available Section */}
        {updateInfo?.updateAvailable && (
          <div className="border border-accent-primary/30 rounded-lg p-4 mb-6">
            <div className="flex items-start gap-3 mb-4">
              <Download size={20} className="text-accent-primary mt-1 flex-shrink-0" />
              <div>
                <h4 className="font-medium text-text-light-primary dark:text-text-primary">
                  {updateInfo.releaseName || `Version ${updateInfo.latestVersion}`}
                </h4>
                <p className="text-sm text-text-light-muted dark:text-text-muted">
                  Released {updateInfo.publishedAt ? new Date(updateInfo.publishedAt).toLocaleDateString() : 'recently'}
                </p>
              </div>
            </div>

            {/* Release Notes */}
            {updateInfo.releaseNotes && (
              <div className="mb-4">
                <h5 className="text-sm font-medium mb-2 text-text-light-primary dark:text-text-primary">Release Notes:</h5>
                <div className="p-3 bg-gray-100 dark:bg-gray-800 rounded text-sm max-h-40 overflow-y-auto">
                  <pre className="whitespace-pre-wrap font-sans text-text-light-secondary dark:text-text-secondary">
                    {updateInfo.releaseNotes}
                  </pre>
                </div>
              </div>
            )}

            {/* Update Instructions */}
            {currentScript && (
              <div className="mb-4">
                <h5 className="text-sm font-medium mb-2 text-text-light-primary dark:text-text-primary">
                  Update Instructions ({isWindows ? 'Windows' : 'Linux'}):
                </h5>
                <ol className="list-decimal list-inside space-y-2 text-sm text-text-light-secondary dark:text-text-secondary">
                  {currentScript.instructions.map((instruction, idx) => (
                    <li key={idx}>{instruction}</li>
                  ))}
                </ol>
              </div>
            )}

            {/* Action Buttons */}
            <div className="flex flex-wrap gap-3">
              {updateInfo.downloadUrl && (
                <a
                  href={updateInfo.downloadUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 px-4 py-2 bg-accent-primary hover:bg-accent-primary/90 text-black font-medium rounded-lg transition-colors"
                >
                  <Download size={16} />
                  Download Release Package
                </a>
              )}
              {updateInfo.releaseUrl && (
                <a
                  href={updateInfo.releaseUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 px-4 py-2 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-text-light-primary dark:text-text-primary rounded-lg transition-colors"
                >
                  <ExternalLink size={16} />
                  View on GitHub
                </a>
              )}
            </div>
          </div>
        )}

        {/* No Update Available */}
        {updateInfo && !updateInfo.updateAvailable && !updateInfo.message?.includes('not configured') && (
          <div className="flex items-center gap-3 p-4 bg-green-500/10 text-green-500 rounded-lg mb-6">
            <Check size={20} />
            <span>You are running the latest version!</span>
          </div>
        )}

        {/* Not configured message */}
        {updateInfo?.message?.includes('not configured') && (
          <div className="flex items-center gap-3 p-4 bg-yellow-500/10 text-yellow-500 rounded-lg mb-6">
            <Info size={20} />
            <span>{updateInfo.message}</span>
          </div>
        )}

        {/* Info Box */}
        <div className="flex items-start gap-3 p-4 bg-blue-500/10 text-blue-400 rounded-lg">
          <Info size={20} className="flex-shrink-0 mt-0.5" />
          <div className="text-sm">
            <p className="font-medium mb-1">Important Update Information</p>
            <ul className="list-disc list-inside space-y-1 text-blue-300">
              <li>Updates require administrator/root privileges</li>
              <li>The server will be stopped during the update</li>
              <li>Your configuration and data will be preserved</li>
              <li>A backup is automatically created before updating</li>
            </ul>
          </div>
        </div>
      </CardContent>
      <CardFooter className="flex items-center justify-between flex-wrap gap-4">
        <div className="text-sm text-text-light-muted dark:text-text-muted">
          {lastChecked && (
            <span>Last checked: {lastChecked.toLocaleString()}</span>
          )}
        </div>
        <div className="flex gap-3">
          {dismissed && updateInfo?.updateAvailable && (
            <Button variant="ghost" size="sm" onClick={resetDismiss}>
              Show Update
            </Button>
          )}
          <Button
            variant="secondary"
            onClick={() => checkForUpdates(true)}
            disabled={isLoading}
            loading={isLoading}
          >
            <RefreshCw size={16} />
            {isLoading ? 'Checking...' : 'Check for Updates'}
          </Button>
        </div>
      </CardFooter>
    </Card>
  );
};
