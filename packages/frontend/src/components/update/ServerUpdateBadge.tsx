import { ArrowUp, RefreshCw } from 'lucide-react';
import { Badge } from '../ui/Badge';
import { useCheckServerUpdate, useRefreshVersionCheck } from '../../hooks/api/useServerUpdates';

interface ServerUpdateBadgeProps {
  serverId: string;
  currentVersion: string;
  compact?: boolean;
  onUpdateClick?: () => void;
}

export const ServerUpdateBadge = ({
  serverId,
  currentVersion,
  compact = false,
  onUpdateClick,
}: ServerUpdateBadgeProps) => {
  const { data: versionCheck, isLoading } = useCheckServerUpdate(serverId, {
    // Only enable if we have a serverId
    enabled: !!serverId,
  });

  const refreshCheck = useRefreshVersionCheck();

  if (isLoading) {
    return (
      <Badge variant="default" size="sm" className="animate-pulse">
        <RefreshCw className="w-3 h-3 mr-1 animate-spin" />
        Checking...
      </Badge>
    );
  }

  if (!versionCheck?.updateAvailable) {
    return null;
  }

  if (compact) {
    return (
      <button
        onClick={onUpdateClick}
        className="flex items-center gap-1 px-2 py-0.5 text-xs font-medium text-white bg-accent-primary rounded-full hover:bg-accent-primary/80 transition-colors"
        title={`Update available: ${versionCheck.availableVersion}`}
      >
        <ArrowUp className="w-3 h-3" />
        Update
      </button>
    );
  }

  return (
    <button
      onClick={onUpdateClick}
      className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-white bg-accent-primary rounded-lg hover:bg-accent-primary/80 transition-colors"
    >
      <ArrowUp className="w-4 h-4" />
      <span>Update to {versionCheck.availableVersion}</span>
    </button>
  );
};

export default ServerUpdateBadge;
