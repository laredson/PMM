# v1.0 packaging notes

The public v1.0 package is a release/branding/documentation freeze over the final accepted preview34 RC5 code line. PMMCore 0.8.1, Mappings, LibraryService, PakService, SaveService, SemanticLab, Common and AssetReader source are unchanged from that final accepted RC package.

Non-functional/source-adjacent release changes: v1.0 visible branding, final documentation, MIT license, third-party notices, history organization, final SmokeTest release identity, and removal of the proprietary Oodle DLL from the distributed ZIP. The pinned repak dependency remains bundled and is responsible for acquiring/loading Oodle when required.
