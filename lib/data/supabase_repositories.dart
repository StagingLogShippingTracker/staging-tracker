// Repository compatibility barrel.
//
// Production implementations live in `slst_shared`; this app file remains
// solely to preserve existing Riverpod provider imports.
export 'package:slst_shared/slst_shared.dart'
    show
        ChangelogRepository,
        NotificationLogRepository,
        NotifyRepository,
        PhotoStorage,
        RosterRepository,
        ShippedRepository,
        StagingRepository;
