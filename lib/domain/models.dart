// Legacy UI import path for domain models owned by slst_shared.
//
// The app keeps its record-based photo picker payload in `data/app_state.dart`
// until that UI transport type can be migrated without changing screens.
export 'package:slst_shared/slst_shared.dart'
    show
        ChangelogEntry,
        ContactPerson,
        ContainerCounts,
        NotificationLogEntry,
        NotificationLogQuery,
        NotificationLogSort,
        ShippedEntry,
        StagingEntry;
