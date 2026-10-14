// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ReadPaper';

  @override
  String get languageMenu => 'Language';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeMenu => 'Theme';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get filesCancel => 'Cancel';

  @override
  String get filesSave => 'Save';

  @override
  String get filesCreate => 'Create';

  @override
  String get filesDelete => 'Delete';

  @override
  String get filesRename => 'Rename';

  @override
  String get filesOpen => 'Open';

  @override
  String get filesShare => 'Share';

  @override
  String get filesPickWorkFolder => 'Choose a work folder';

  @override
  String get filesWorkFolderNotReady =>
      'The work folder is not ready. Choose another folder with the folder icon.';

  @override
  String get filesPickFilesToCopy => 'Choose files to copy here';

  @override
  String filesCopiedHere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 copied here';
  }

  @override
  String get filesNameTaken => 'A file or folder with that name already exists';

  @override
  String filesRenameFailed(String error) {
    return 'Rename failed: $error';
  }

  @override
  String get filesCannotDeleteRoot =>
      'The work folder itself cannot be deleted from here.';

  @override
  String get filesDeleteFolderTitle => 'Delete this folder?';

  @override
  String get filesFolderEmpty => 'The folder is empty.';

  @override
  String get filesFolderUncountable => 'Its contents could not be counted.';

  @override
  String filesFolderDeletesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 inside will be deleted too.';
  }

  @override
  String get filesLibraryCopiesUntouched =>
      'Copies already in the library are not touched.';

  @override
  String filesDeleteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Delete $_temp0';
  }

  @override
  String filesDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get filesDeleteFileTitle => 'Delete this file?';

  @override
  String filesDeleteFileBody(String name) {
    return '$name\n\nRemoved from this folder. Copies already in the library are not touched.';
  }

  @override
  String get filesNewBoardTitle => 'New whiteboard';

  @override
  String get filesNewBoardBody =>
      'Several sheets to draw on, then saved as a PDF in this folder.';

  @override
  String get filesPortrait => 'Portrait';

  @override
  String get filesLandscape => 'Landscape';

  @override
  String filesSavedHere(String name) {
    return '$name saved in this folder';
  }

  @override
  String get filesNewFolderTitle => 'New folder';

  @override
  String get filesNameLabel => 'Name';

  @override
  String get filesNewMarkdownTitle => 'New Markdown file';

  @override
  String get filesFileNameLabel => 'File name';

  @override
  String get filesNewNotebookTitle => 'New notebook';

  @override
  String get filesHeader => 'Files';

  @override
  String get filesUpOneLevel => 'Up one level';

  @override
  String get filesCreateHere => 'Create new in this folder';

  @override
  String get filesWhiteboard => 'Whiteboard';

  @override
  String get filesNotebook => 'Notebook';

  @override
  String get filesMarkdownFile => 'Markdown file';

  @override
  String get filesFolder => 'Folder';

  @override
  String get filesCopyInTooltip =>
      'Copy files or a folder here — from anywhere on this device';

  @override
  String get filesPickFolderToCopy => 'Choose a folder to copy here';

  @override
  String get filesCopyFiles => 'Copy files…';

  @override
  String get filesCopyFolder => 'Copy folder (with its contents)…';

  @override
  String get filesOpenOtherFolder => 'Open another folder';

  @override
  String get filesEmptyFolderHint =>
      'This folder is empty.\n\nCreate a whiteboard, or copy PDFs here with the download button above — then drag them onto a collection to add them to the library.';

  @override
  String get filesFolderActions => 'Folder actions';

  @override
  String get filesDeleteFolder => 'Delete folder';

  @override
  String get filesFileActions => 'File actions';

  @override
  String get filesDeleteFile => 'Delete file';

  @override
  String filesCannotOpenExt(String ext) {
    return '$ext files cannot be opened inside ReadPaper yet. Supported: PDF, EPUB, images, CSV and Excel.';
  }

  @override
  String get filesCannotOpenThis =>
      'This file cannot be opened inside ReadPaper yet. Supported: PDF, EPUB, images, CSV and Excel.';

  @override
  String filesNoAppForExt(String ext) {
    return 'No application on this system opens $ext files.';
  }

  @override
  String get filesNoAppForThis =>
      'No application on this system opens this file.';

  @override
  String get filesOpenWithOtherApp => 'Open with another app';

  @override
  String filesTableUnreadable(String error) {
    return 'This table cannot be read: $error';
  }

  @override
  String get filesNoSheets => 'There are no sheets in this file.';

  @override
  String get filesSheetEmpty => 'This sheet is empty.';

  @override
  String filesOnlyFirstRows(int count) {
    return 'Only the first $count rows are shown. Open with another app to see them all.';
  }

  @override
  String get settingsRepositories => 'Repositories';

  @override
  String get settingsAddRepository => 'Add repository';

  @override
  String get settingsNoRepositories => 'No repositories yet.';

  @override
  String settingsDeleteProfileTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get settingsDeleteProfileBody =>
      'The profile will be removed from ReadPaper.';

  @override
  String get settingsDeleteCloneToo => 'Also delete the local clone folder';

  @override
  String settingsUrlTransportMismatch(String mode) {
    return 'The URL does not match the $mode mode.';
  }

  @override
  String get settingsMakeActive => 'Make active';

  @override
  String get settingsLicense =>
      'Free software, licensed AGPL-3.0-or-later.\nSource code: github.com/situkangsayur/readpaper';

  @override
  String get settingsEditRepository => 'Edit repository';

  @override
  String get settingsRepoUrl => 'Repository URL';

  @override
  String get settingsUrlRequired => 'The URL must not be empty';

  @override
  String get settingsApiTokenNote =>
      'This device syncs through the GitHub API, so access uses an HTTPS token.';

  @override
  String get settingsDisplayName => 'Display name';

  @override
  String get settingsNameRequired => 'The name must not be empty';

  @override
  String get settingsSshKeyOptional => 'SSH private key (optional)';

  @override
  String get settingsSshKeyHelper =>
      'Leave empty to use ssh-agent or the default key.';

  @override
  String get settingsGithubUsername => 'GitHub username';

  @override
  String get settingsAccessToken => 'Personal access token';

  @override
  String get settingsTokenHelper =>
      'Stored separately in credentials.json (permission 600).';

  @override
  String get settingsLocalCloneFolder => 'Local clone folder';

  @override
  String get settingsPrivateStorage =>
      'Data is kept in the app\'s private storage.';

  @override
  String get settingsCommitIdentity => 'Commit identity';

  @override
  String get settingsNameLabel => 'Name';

  @override
  String get settingsAuthorHint => 'empty = use the git configuration';

  @override
  String get settingsLazyPdfTitle => 'Download PDFs only when opened';

  @override
  String get settingsLazyPdfSubtitle =>
      'Fetch the library metadata first (tens of MB); PDFs follow one by one. Turn off to download every PDF after fetch and pull, so they can be read offline.';

  @override
  String get settingsAutoPushTitle =>
      'Push automatically after saving an annotation';

  @override
  String get settingsAutoPushSubtitle =>
      'Every highlight/comment is sent to GitHub right away.';

  @override
  String get settingsPickSshKey => 'Choose an SSH private key';

  @override
  String get settingsPickCloneFolder => 'Choose a clone folder';

  @override
  String citationRunningAt(String address) {
    return 'Running at $address';
  }

  @override
  String get citationOff =>
      'Off. The Word and OnlyOffice add-ins cannot connect.';

  @override
  String get citationStarting => 'Starting…';

  @override
  String get citationTitle => 'Citations in Word & OnlyOffice';

  @override
  String get citationSubtitle =>
      'Local server the add-ins use to search and cite.';

  @override
  String get citationRetry => 'Retry';

  @override
  String get citationAddress => 'Address';

  @override
  String get citationCopyAddress => 'Copy address';

  @override
  String get citationAddressCopied => 'Address copied.';

  @override
  String get citationNoToken => 'None yet';

  @override
  String get citationHideToken => 'Hide token';

  @override
  String get citationShowToken => 'Show token';

  @override
  String get citationCopyToken => 'Copy token';

  @override
  String get citationTokenCopied => 'Token copied.';

  @override
  String get citationNewToken => 'Create a new token';

  @override
  String get citationPasteHint =>
      'Paste this address and token into the add-in. Guide: docs/api-sitasi.md in the ReadPaper repository.';

  @override
  String get citationNewTokenTitle => 'Create a new token?';

  @override
  String get citationNewTokenBody =>
      'The old token stops working immediately. Word and OnlyOffice add-ins that are already connected must be given the new token.';

  @override
  String get citationCreateNew => 'Create new';

  @override
  String citationTokenSaveFailed(String error) {
    return 'The new token could not be saved: $error';
  }

  @override
  String citationSettingsUnreadable(String error) {
    return 'The citation server settings could not be read: $error';
  }

  @override
  String citationPortInUse(int port, String reason) {
    return 'Port $port is already used by another program (perhaps another ReadPaper window). $reason';
  }

  @override
  String get citationEmptyCollection => 'This collection has no papers yet.';

  @override
  String citationBibWritten(int count, String file) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0 written to $file in the work folder';
  }

  @override
  String citationBibCopied(String key) {
    return 'BibTeX copied — key $key';
  }

  @override
  String get commonColorYellow => 'Yellow';

  @override
  String get commonColorRed => 'Red';

  @override
  String get commonColorGreen => 'Green';

  @override
  String get commonColorBlue => 'Blue';

  @override
  String get commonColorPurple => 'Purple';

  @override
  String get commonColorMagenta => 'Magenta';

  @override
  String get commonColorOrange => 'Orange';

  @override
  String get commonColorGray => 'Gray';

  @override
  String get commonColorTeal => 'Teal';

  @override
  String get commonColorPink => 'Pink';

  @override
  String get commonColorBrown => 'Brown';

  @override
  String get commonColorInk => 'Ink';

  @override
  String get commonColorWhite => 'White';

  @override
  String get commonColorBlack => 'Black';

  @override
  String get commonColorGrayShort => 'Gray';

  @override
  String get commonColorOrangeInk => 'Orange';

  @override
  String get commonColorLightGreen => 'Light green';

  @override
  String get commonColorSkyBlue => 'Sky blue';

  @override
  String get commonColorNavyBlue => 'Navy blue';

  @override
  String get commonFilePickUnreadable =>
      'That file cannot be read where it is. Copy it to the work folder first.';

  @override
  String commonFilePickerFailed(String error) {
    return 'The file picker could not be opened: $error';
  }

  @override
  String commonFolderPickerFailed(String error) {
    return 'The folder picker could not be opened: $error';
  }

  @override
  String commonLinuxPickerHelp(String error) {
    return 'The file dialog could not be opened ($error). Install xdg-desktop-portal with a backend (e.g. xdg-desktop-portal-gtk), or zenity.';
  }

  @override
  String commonShareUnsupported(String error, String path) {
    return 'Sharing files is not supported here yet ($error). The file is at $path';
  }

  @override
  String get commonJustNow => 'just now';

  @override
  String commonMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String commonHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String commonDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0 ago';
  }

  @override
  String commonWeeksAgo(int count) {
    return '$count weeks ago';
  }

  @override
  String commonMonthsAgo(int count) {
    return '$count months ago';
  }

  @override
  String commonYearsAgo(int count) {
    return '$count years ago';
  }

  @override
  String get commonWorkFolder => 'Work folder';

  @override
  String get commonYesterday => 'yesterday';

  @override
  String get commonShapeRectangle => 'Rectangle';

  @override
  String get commonShapeEllipse => 'Ellipse';

  @override
  String get commonShapeDiamond => 'Diamond';

  @override
  String get commonShapeTriangle => 'Triangle';

  @override
  String get commonShapeLine => 'Line';

  @override
  String get commonShapeArrow => 'Arrow';

  @override
  String get findTooltip => 'Find in document (Ctrl+F)';

  @override
  String get findHint => 'Find…';

  @override
  String get findSearching => 'Searching…';

  @override
  String get findNoResults => 'No results';

  @override
  String findCount(int current, int total) {
    return '$current of $total';
  }

  @override
  String get findPrevious => 'Previous (Shift+Enter)';

  @override
  String get findNext => 'Next (Enter)';

  @override
  String get findClose => 'Close search (Esc)';

  @override
  String findInChapter(int chapter) {
    return 'Chapter $chapter';
  }

  @override
  String get githubLoginButton => 'Sign in with GitHub';

  @override
  String get githubLoginButtonHint =>
      'No token needed: sign in in the browser, then pick or create the library repository.';

  @override
  String get githubLoginTitle => 'Sign in with GitHub';

  @override
  String get githubLoginCancel => 'Cancel';

  @override
  String get githubLoginRetry => 'Try again';

  @override
  String get githubLoginStep1 =>
      'Open GitHub, enter this code, then press Authorize. The code is already on your clipboard.';

  @override
  String get githubLoginCopyCode => 'Copy code';

  @override
  String get githubLoginOpen => 'Open GitHub';

  @override
  String get githubLoginWaiting => 'Waiting for approval on GitHub…';

  @override
  String githubLoginSignedIn(String login) {
    return 'Signed in as $login';
  }

  @override
  String get githubLoginChooseRepo => 'Choose the library repository:';

  @override
  String get githubLoginSearchRepo => 'Search repositories…';

  @override
  String get githubLoginNoRepos =>
      'No repositories you can write to. Create one below.';

  @override
  String get githubLoginCreateTitle => 'No repository yet?';

  @override
  String get githubLoginCreateHint =>
      'ReadPaper creates it in your GitHub account, with a README so it can be fetched right away.';

  @override
  String get githubLoginRepoName => 'New repository name';

  @override
  String get githubLoginPrivate => 'Private (only you can see it)';

  @override
  String get githubLoginCreate => 'Create repository';

  @override
  String get githubLoginExpired =>
      'The code expired before it was approved. Try again.';

  @override
  String get githubLoginDenied => 'Access was denied on GitHub.';

  @override
  String githubLoginFailed(String detail) {
    return 'Could not sign in to GitHub: $detail';
  }

  @override
  String githubRepoNameTaken(String name) {
    return 'Repository \"$name\" already exists in this account, or the name is invalid. Choose another name, or pick it from the list above.';
  }

  @override
  String githubLoginDone(String login, String repo) {
    return 'Signed in as $login — repository $repo chosen. Review, then Save.';
  }

  @override
  String get githubLoginChooseAccount =>
      'Use an account you already signed in with, or sign in with another one:';

  @override
  String githubLoginUseAccount(String login) {
    return 'Use account $login';
  }

  @override
  String get githubLoginForgetAccount => 'Forget this account on this device';

  @override
  String get githubLoginOtherAccount => 'Sign in with another account';

  @override
  String get libraryAddToLibraryTooltip =>
      'Add files or a folder to the library';

  @override
  String get libraryAddFiles => 'Add files…';

  @override
  String get libraryAddFolderAsCollection =>
      'Add a folder (becomes a collection)…';

  @override
  String get libraryNewPaperCollection => 'New paper collection';

  @override
  String get libraryUnfiled => 'Unfiled';

  @override
  String get libraryNotesRoot => 'Notes';

  @override
  String get libraryNewNoteCollection => 'New note collection';

  @override
  String libraryItemsAndCollections(int items, int collections) {
    String _temp0 = intl.Intl.pluralLogic(
      items,
      locale: localeName,
      other: '$items items',
      one: '1 item',
    );
    String _temp1 = intl.Intl.pluralLogic(
      collections,
      locale: localeName,
      other: '$collections collections',
      one: '1 collection',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get libraryIncludeSubOn => 'Include sub-collection items: on';

  @override
  String get libraryIncludeSubOff => 'Include sub-collection items: off';

  @override
  String get libraryCollapseAll => 'Collapse all';

  @override
  String get libraryExpandAll => 'Expand all';

  @override
  String get libraryNoNoteCollections =>
      'No note collections yet. Notes live in their own folder inside the repository, separate from papers.';

  @override
  String get libraryNewSubcollectionHere => 'New sub-collection here';

  @override
  String get libraryCollectionMenu => 'Rename, move, or delete';

  @override
  String get libraryNewPaperSubcollection => 'New paper sub-collection';

  @override
  String get libraryNewCollectionHint =>
      'Written to collections.json and synced to GitHub';

  @override
  String get libraryCreateCollectionFailed => 'Could not create the collection';

  @override
  String get libraryNewNoteSubcollection => 'New note sub-collection';

  @override
  String get libraryAddFilesHere => 'Add files here…';

  @override
  String get libraryAnyTypeOrDrag =>
      'any type, several at once; or drag from your file manager';

  @override
  String get libraryAnyTypeSeveral => 'any type, several at once';

  @override
  String get libraryAddFolderHere => 'Add a folder here…';

  @override
  String get librarySubfoldersBecomeSub => 'subfolders become sub-collections';

  @override
  String get libraryNewSubcollection => 'New sub-collection';

  @override
  String get libraryRename => 'Rename';

  @override
  String get libraryMoveTo => 'Move to…';

  @override
  String get libraryTransferToRepo => 'Move or copy to another repository…';

  @override
  String get libraryWithSubsAndPapers => 'with its sub-collections and papers';

  @override
  String get libraryExportBibtex => 'Export to BibTeX (.bib)';

  @override
  String get libraryExportBibtexHint =>
      'for LaTeX manuscripts; sub-collections included';

  @override
  String get libraryDeleteCollection => 'Delete collection';

  @override
  String get libraryPapersKept => 'The papers in it are not deleted';

  @override
  String get libraryChangeCollectionFailed => 'Could not change the collection';

  @override
  String get libraryRenameCollection => 'Rename collection';

  @override
  String get libraryRenameCollectionHint =>
      'Its papers stay; its sub-collection paths follow';

  @override
  String libraryCollectionRenamed(String name) {
    return 'Collection renamed to \"$name\"';
  }

  @override
  String get libraryRoot => 'the root';

  @override
  String libraryCollectionMoved(String parent) {
    return 'Collection moved to $parent';
  }

  @override
  String libraryTransferWhatCollection(String path) {
    return 'Collection $path, with its sub-collections and papers';
  }

  @override
  String libraryCollectionMovedToRepo(String name, String repo) {
    return 'Collection \"$name\" moved to $repo';
  }

  @override
  String libraryCollectionCopiedToRepo(String name, String repo) {
    return 'Collection \"$name\" copied to $repo';
  }

  @override
  String libraryConfirmDeleteCollection(String name) {
    return 'Delete collection \"$name\"?';
  }

  @override
  String libraryDeleteKeepsPapers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count papers',
      one: '1 paper',
    );
    return 'The $_temp0 in it are not deleted — only removed from this collection, just like in Zotero.';
  }

  @override
  String libraryDeleteHasChildren(int count) {
    return 'This collection has $count sub-collections. Delete them too, or move them up one level?';
  }

  @override
  String get libraryCollectionEmpty => 'The collection is empty.';

  @override
  String get libraryCancel => 'Cancel';

  @override
  String get librarySubsMoveUp => 'Move sub-collections up';

  @override
  String get libraryYesDeleteAll => 'Yes, delete everything';

  @override
  String get libraryYesDelete => 'Yes, delete';

  @override
  String libraryCollectionDeleted(String name) {
    return 'Collection \"$name\" deleted; its papers remain';
  }

  @override
  String libraryMoveNameTo(String name) {
    return 'Move \"$name\" to…';
  }

  @override
  String get libraryLibraryRoot => 'Library root';

  @override
  String get libraryNoParent => 'no parent';

  @override
  String get libraryWithSubsAndNotes => 'with its sub-collections and notes';

  @override
  String get libraryNotesKept => 'Its notes are not deleted';

  @override
  String libraryTransferWhatNoteCollection(String name) {
    return 'Note collection \"$name\", with its sub-collections and notes';
  }

  @override
  String libraryNoteCollectionMovedToRepo(String name, String repo) {
    return 'Note collection \"$name\" moved to $repo';
  }

  @override
  String libraryNoteCollectionCopiedToRepo(String name, String repo) {
    return 'Note collection \"$name\" copied to $repo';
  }

  @override
  String libraryConfirmDeleteNoteCollection(String name) {
    return 'Delete note collection \"$name\"?';
  }

  @override
  String libraryNoteCollectionHolds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return 'Holds $_temp0. They are not deleted — they move to \"Unfiled\" if they are in no other collection.';
  }

  @override
  String librarySubsDeletedToo(int count) {
    return 'Its $count sub-collections are deleted too.';
  }

  @override
  String get libraryName => 'Name';

  @override
  String get librarySave => 'Save';

  @override
  String get libraryNoItems => 'No items.';

  @override
  String get librarySearchHelpTitle => 'Narrowing a search';

  @override
  String get librarySearchHelpIntro =>
      'Plain words are searched in the title, authors, journal, tags, collections, DOI and abstract. Several words must all match.';

  @override
  String get librarySearchOpAuthor => 'only in author names';

  @override
  String get librarySearchOpTitle => 'exact phrase in the title';

  @override
  String get librarySearchOpYear => 'exact year';

  @override
  String get librarySearchOpTag => 'only in tags';

  @override
  String get librarySearchOpType => 'Zotero item type';

  @override
  String get librarySearchOpJournal => 'publication name';

  @override
  String get librarySearchOpAbstract => 'only in the abstract';

  @override
  String get librarySearchOpCollection => 'collection name';

  @override
  String get librarySearchOpExclude => 'exclude items containing it';

  @override
  String get librarySearchHelpEnglish =>
      'Field names may also be in English: author, title, year, type, journal, abstract, collection.';

  @override
  String get libraryClose => 'Close';

  @override
  String get librarySearchHint => 'Search titles, authors, abstracts, DOIs…';

  @override
  String get librarySearchHelpTooltip => 'How to narrow a search';

  @override
  String get libraryOpenAnyFile =>
      'Open a file from this device (without adding it to the library)';

  @override
  String get libraryPickFileToOpen => 'Choose a file to open';

  @override
  String get libraryFindDuplicates => 'Find items added more than once';

  @override
  String libraryPossibleDuplicates(int count) {
    return '$count possible duplicates';
  }

  @override
  String get libraryStats => 'Library statistics';

  @override
  String get libraryBrowseByAuthor => 'Browse by author';

  @override
  String librarySortBy(String label) {
    return 'Sort: $label';
  }

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get libraryHasFile => 'file';

  @override
  String get libraryNoFile => 'no file';

  @override
  String get libraryPickPaper => 'Choose a paper to see its details.';

  @override
  String get libraryAbstract => 'Abstract';

  @override
  String libraryAnnotationsCount(int count) {
    return 'Annotations ($count)';
  }

  @override
  String libraryNotesCount(int count) {
    return 'Notes ($count)';
  }

  @override
  String get libraryCopyBibtex => 'Copy BibTeX';

  @override
  String get libraryDeleteDocument => 'Remove this document from the library';

  @override
  String get libraryBackToList => 'Back to the list';

  @override
  String get libraryNoAttachments => 'No attachments.';

  @override
  String libraryAnnotationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annotations',
      one: '1 annotation',
    );
    return '$_temp0';
  }

  @override
  String get libraryOnGithubNotDownloaded => 'on GitHub, not downloaded yet';

  @override
  String get libraryFileNotDownloaded => 'file not downloaded yet';

  @override
  String get libraryLfsPointer => 'Git LFS pointer — run LFS pull';

  @override
  String get libraryCannotOpenFormat =>
      'this format cannot be opened on this device yet';

  @override
  String get libraryRead => 'Read';

  @override
  String get libraryOpen => 'Open';

  @override
  String get libraryDownload => 'Download';

  @override
  String get libraryFieldAuthors => 'Authors';

  @override
  String get libraryFieldPublication => 'Publication';

  @override
  String get libraryFieldDate => 'Date';

  @override
  String get libraryFieldPublisher => 'Publisher';

  @override
  String get libraryFieldTags => 'Tags';

  @override
  String get libraryFieldCollections => 'Collections';

  @override
  String get libraryFieldAdded => 'Added';

  @override
  String get libraryDetails => 'Details';

  @override
  String libraryAnnotationPage(String page, String type) {
    return 'p. $page · $type';
  }

  @override
  String libraryMovingTo(String target) {
    return 'Moving to $target…';
  }

  @override
  String libraryCopyingTo(String target) {
    return 'Copying to $target…';
  }

  @override
  String libraryMovedTo(String where) {
    return 'Moved to $where';
  }

  @override
  String libraryCopiedTo(String where) {
    return 'Copied to $where';
  }

  @override
  String get libraryConfirmDeleteDocument => 'Remove this document?';

  @override
  String libraryConfirmDeleteDocumentBody(String title) {
    return 'The item file, its attachments and its notes are removed from the library, and the change is committed.\n\n\"$title\"\n\nCollections and other documents are untouched.';
  }

  @override
  String get libraryDelete => 'Delete';

  @override
  String get libraryDocumentDeleted => 'Document removed';

  @override
  String get libraryDeleteFailed => 'Could not delete';

  @override
  String get libraryRecentlyRead => 'Recently read';

  @override
  String get libraryClearHistory => 'Clear';

  @override
  String libraryPageN(int page) {
    return 'page $page';
  }

  @override
  String get libraryRemoveFromHistory => 'Remove from history';

  @override
  String libraryAuthorsCount(int count) {
    return 'Authors ($count)';
  }

  @override
  String get libraryMostWorks => 'Most works';

  @override
  String get libraryFilterNames => 'Filter names';

  @override
  String get libraryNoLibraryRead => 'No library has been read yet.';

  @override
  String get libraryNoMatchingNames => 'No matching names.';

  @override
  String get libraryDuplicatesTitle => 'Possible duplicates';

  @override
  String libraryDuplicatesNone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0 checked, nothing suspicious.';
  }

  @override
  String libraryDuplicatesSummary(int groups, int copies, int items) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups groups',
      one: '1 group',
    );
    String _temp1 = intl.Intl.pluralLogic(
      copies,
      locale: localeName,
      other: '$copies copies',
      one: '1 copy',
    );
    String _temp2 = intl.Intl.pluralLogic(
      items,
      locale: localeName,
      other: '$items items',
      one: '1 item',
    );
    return '$_temp0 · $_temp1 out of $_temp2';
  }

  @override
  String libraryDuplicatesRisky(int count) {
    return ' · $count need care';
  }

  @override
  String get libraryNothingDuplicated => 'Nothing looks duplicated.';

  @override
  String get libraryDuplicatesHow =>
      'Matched by DOI, then ISBN, then title together with year and first author.';

  @override
  String get libraryDuplicatesFooter =>
      'Nothing is deleted from here. Merging is done in Zotero, where history and attachments move along — this list shows what needs a look.';

  @override
  String libraryCopiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies',
      one: '1 copy',
    );
    return '$_temp0';
  }

  @override
  String get libraryAnnotationsOnSeveral =>
      'Annotations are on more than one copy — merging could lose some of them.';

  @override
  String get libraryHasFileFact => 'has a file';

  @override
  String get libraryStatsEmpty => 'No items to count yet.';

  @override
  String get libraryStatsByYear => 'By publication year';

  @override
  String libraryStatsWithoutYear(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0 without a year are not counted here.';
  }

  @override
  String get libraryStatsByType => 'By type';

  @override
  String get libraryStatsTopAuthors => 'Most frequent authors';

  @override
  String get libraryStatsTopTags => 'Most frequent tags';

  @override
  String get libraryStatsItems => 'Items';

  @override
  String get libraryStatsWithFile => 'File present';

  @override
  String get libraryStatsWithAnnotations => 'With annotations';

  @override
  String get libraryStatsYearSpan => 'Year range';

  @override
  String get libraryStatsUntitled => 'Untitled';

  @override
  String get librarySortTitle => 'Title';

  @override
  String get librarySortYear => 'Year';

  @override
  String get librarySortCreator => 'Author';

  @override
  String get librarySortDateAdded => 'Date added';

  @override
  String get librarySortAnnotations => 'Annotations';

  @override
  String libraryPickFolderFor(String name) {
    return 'Choose a folder for $name';
  }

  @override
  String libraryPickFilesFor(String name) {
    return 'Choose files for $name';
  }

  @override
  String libraryFilesAdded(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 added to $name';
  }

  @override
  String libraryFilesAddedPartly(
    int added,
    int total,
    String name,
    String failed,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total files',
      one: '1 file',
    );
    return '$added of $_temp0 added to $name. Failed: $failed. ';
  }

  @override
  String libraryMovingInto(String name) {
    return 'Moving to $name…';
  }

  @override
  String libraryMovedInto(String name) {
    return 'Moved to $name';
  }

  @override
  String get libraryMoveFailed => 'Could not move';

  @override
  String libraryAddingInto(String name) {
    return 'Adding to $name…';
  }

  @override
  String get libraryAddFileFailed => 'Could not add the file';

  @override
  String libraryAddedInto(String name) {
    return 'Added to $name';
  }

  @override
  String get libraryPapersStayInLibrary =>
      'Papers stay under the paper root: Zotero items carry citations and bibliography kept by the sync plugin, and the notes folder knows nothing of them. Only notes can be moved here.';

  @override
  String get libraryMoveNoteFailed => 'Could not move the note';

  @override
  String get librarySaveNoteFailed => 'Could not save the note';

  @override
  String libraryFolderEmpty(String name) {
    return 'Folder $name contains no files.';
  }

  @override
  String libraryImportFolderQuestion(String folder, String name) {
    return 'Import folder \"$folder\" into $name?';
  }

  @override
  String libraryFolderSummary(int files, int folders, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files files',
      one: '1 file',
    );
    String _temp1 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders folders',
      one: '1 folder',
    );
    return '$_temp0 in $_temp1 ($size).';
  }

  @override
  String get libraryFolderToNotes =>
      'This folder becomes a note collection, its subfolders sub-collections, and every file a note.';

  @override
  String get libraryFolderToLibrary =>
      'This folder becomes a collection, its subfolders sub-collections, and every file a Zotero item with its attachment — visible in Zotero too.';

  @override
  String get libraryFolderReuses =>
      'Collections with the same name in the same place are reused, not duplicated.';

  @override
  String get libraryFolderLarge =>
      'It is large. All these files go into the git repository and are sent to GitHub.';

  @override
  String get libraryImport => 'Import';

  @override
  String libraryImporting(String name) {
    return 'Importing $name…';
  }

  @override
  String libraryProgress(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total files',
      one: '1 file',
    );
    return '$done of $_temp0';
  }

  @override
  String get libraryImportFailed => 'Folder import failed';

  @override
  String libraryImportDone(int added, int collections) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added files',
      one: '1 file',
    );
    return '$_temp0 added, $collections new collections.';
  }

  @override
  String libraryImportFailedSome(int count, String names) {
    return 'Failed ($count): $names';
  }

  @override
  String libraryAddToTooltip(String name) {
    return 'Add files or a folder to $name';
  }

  @override
  String get libraryAnyTypeMany => 'any type, several at once';

  @override
  String get libraryAddFolder => 'Add a folder…';

  @override
  String libraryAddFolderHint(String name) {
    return 'becomes a collection in $name, subfolders become sub-collections';
  }

  @override
  String get libraryTypeJournalArticle => 'Journal article';

  @override
  String get libraryTypeConferencePaper => 'Conference paper';

  @override
  String get libraryTypeBook => 'Book';

  @override
  String get libraryTypeBookSection => 'Book section';

  @override
  String get libraryTypeThesis => 'Thesis / dissertation';

  @override
  String get libraryTypeReport => 'Report';

  @override
  String get libraryTypePreprint => 'Preprint';

  @override
  String get libraryTypeWebpage => 'Web page';

  @override
  String get libraryTypeManuscript => 'Manuscript';

  @override
  String get libraryTypeDocument => 'Document';

  @override
  String get libraryTypePresentation => 'Presentation';

  @override
  String get libraryTypeDataset => 'Dataset';

  @override
  String get libraryTypeStandard => 'Standard';

  @override
  String get libraryTypePatent => 'Patent';

  @override
  String get libraryTypeMagazineArticle => 'Magazine article';

  @override
  String get libraryTypeNewspaperArticle => 'Newspaper article';

  @override
  String get libraryTypeEncyclopediaArticle => 'Encyclopedia article';

  @override
  String get libraryTypeBlogPost => 'Blog post';

  @override
  String get libraryTypeComputerProgram => 'Software';

  @override
  String get libraryTypeAttachment => 'Attachment';

  @override
  String get libraryTypeNote => 'Note';

  @override
  String get libraryReasonDoi => 'Same DOI';

  @override
  String get libraryReasonIsbn => 'Same ISBN';

  @override
  String get libraryReasonTitleYearAuthor => 'Same title, year and author';

  @override
  String get libraryErrItemNotFound => 'Item file not found';

  @override
  String get libraryErrLibraryDirMissing => 'Library directory does not exist';

  @override
  String get libraryErrItemInvalid => 'Invalid item file';

  @override
  String libraryErrAttachmentsMissing(int count, String names) {
    return '$count attachments are not on this device yet (not downloaded, or still Git LFS pointers): $names';
  }

  @override
  String get libraryErrItemNoKey => 'The item file has no Zotero key';

  @override
  String libraryErrItemExistsInTarget(String itemKey) {
    return 'This item already exists in the target repository (key $itemKey). It is not copied twice.';
  }

  @override
  String get libraryErrCollectionGone => 'The collection no longer exists';

  @override
  String get libraryErrTargetCollectionMissing =>
      'The target collection does not exist';

  @override
  String libraryErrTargetHasCollection(String name) {
    return 'The target already has a collection named \"$name\". Rename it first.';
  }

  @override
  String libraryErrItemTitleExists(String title) {
    return 'Item $title already exists in the target repository.';
  }

  @override
  String get libraryErrCollectionsNotList =>
      'collections.json does not contain a list of collections';

  @override
  String get libraryErrRefuseDeleteNotItem =>
      'Refusing to delete: this file is not an item inside items/';

  @override
  String get libraryErrCollectionNameEmpty =>
      'The collection name cannot be empty';

  @override
  String get libraryErrCollectionNameSlash =>
      'The collection name cannot contain a slash';

  @override
  String get libraryErrCollectionsNotListRefuse =>
      'collections.json does not contain a list of collections — refusing to write it';

  @override
  String get libraryErrCollectionsBadEntry =>
      'An entry in collections.json is not a collection — refusing to write it';

  @override
  String get libraryErrParentMissing => 'The parent collection does not exist';

  @override
  String libraryErrCollectionExists(String name) {
    return 'A collection named \"$name\" already exists in the same place';
  }

  @override
  String get libraryErrCollectionKey => 'Could not create a new collection key';

  @override
  String get libraryErrMoveIntoSelf =>
      'A collection cannot be moved into itself';

  @override
  String get libraryErrCollectionsMissing => 'collections.json does not exist';

  @override
  String get libraryErrItemNoZotero => 'The item file has no zotero section';

  @override
  String get libraryErrFileNotFound => 'File not found';

  @override
  String get notesUnfiledTitle => 'Unfiled notes';

  @override
  String get notesRootTitle => 'Notes';

  @override
  String get notesAllTitle => 'All notes';

  @override
  String notesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String get notesNewNotebook => 'New notebook';

  @override
  String get notesNewMarkdown => 'New Markdown note';

  @override
  String get notesEmpty =>
      'No notes here yet. Drag files from the file panel, or use the add button above. Pull down to fetch changes from GitHub.';

  @override
  String get notesActions => 'Actions';

  @override
  String get notesClose => 'Close';

  @override
  String get notesNotebookDefaultTitle => 'Note';

  @override
  String get notesNewNotebookFailed => 'Could not create the notebook';

  @override
  String get notesNewNoteTitle => 'New note';

  @override
  String get notesNewNoteFailed => 'Could not create the note';

  @override
  String get notesRename => 'Rename';

  @override
  String get notesShare => 'Share';

  @override
  String get notesShareAsPdf => 'as PDF';

  @override
  String get notesShareToApps => 'to other apps';

  @override
  String get notesMoveToCollection => 'Move to collection';

  @override
  String get notesTransferToRepo => 'Move or copy to another repository…';

  @override
  String get notesDelete => 'Delete note';

  @override
  String get notesDeleteSubtitle => 'Its file is deleted too';

  @override
  String notesTransferWhat(String title) {
    return 'Note \"$title\"';
  }

  @override
  String notesMoved(String target) {
    return 'Note moved to $target';
  }

  @override
  String notesCopied(String target) {
    return 'Note copied to $target';
  }

  @override
  String get notesDeleteConfirmTitle => 'Delete note?';

  @override
  String notesDeleteConfirmBody(String title) {
    return '“$title” and its file will be deleted from the repository.';
  }

  @override
  String get notesCancel => 'Cancel';

  @override
  String get notesDeleteButton => 'Delete';

  @override
  String get notesNoCollection => 'No collection';

  @override
  String get notesTitleField => 'Title';

  @override
  String get notesSave => 'Save';

  @override
  String get notesNoActiveRepo => 'No active repository yet.';

  @override
  String get notesNoteGone => 'The note no longer exists.';

  @override
  String get notesCollectionGone => 'The collection no longer exists.';

  @override
  String get notesNoRepoToSave => 'No active repository to save notes in.';

  @override
  String get notesErrEmptyCollectionName =>
      'A note collection name cannot be empty';

  @override
  String get notesErrParentMissing => 'The parent collection does not exist';

  @override
  String get notesErrCollectionMissing => 'The note collection does not exist';

  @override
  String get notesErrFileNotFound => 'Note file not found';

  @override
  String get notesErrNoteMissing => 'The note does not exist';

  @override
  String get notesErrEmptyTitle => 'A note title cannot be empty';

  @override
  String get notesErrTargetCollectionMissing =>
      'The target note collection does not exist';

  @override
  String get notesErrFileOutside => 'The note file is outside the notes folder';

  @override
  String get notesErrFileNotOnDevice => 'The note file is not on this device';

  @override
  String notesErrTargetNameTaken(String name) {
    return 'The destination already has a note collection named \"$name\". Rename it first.';
  }

  @override
  String notesErrNamedFileNotOnDevice(String title) {
    return 'The file of note \"$title\" is not on this device';
  }

  @override
  String get notesErrNoNewKey => 'Could not create a new note key';

  @override
  String get notesTargetRefusal =>
      'Notes can only be stored under the \"Notes\" root. The paper root holds Zotero items — they carry citation and bibliography properties, and their format is kept by the Zotero sync plugin. Choose a collection under the Notes root, or create one first.';

  @override
  String notesImageMissing(String path) {
    return 'The image file no longer exists:\n$path';
  }

  @override
  String get epubThemeLight => 'Light';

  @override
  String get epubThemeSepia => 'Sepia';

  @override
  String get epubThemeDark => 'Dark';

  @override
  String epubUnreadable(String error) {
    return 'This EPUB cannot be read: $error';
  }

  @override
  String get epubSmallerText => 'Smaller text';

  @override
  String get epubLargerText => 'Larger text';

  @override
  String epubPageColor(String name) {
    return 'Page colour: $name';
  }

  @override
  String get epubContents => 'Contents';

  @override
  String get epubNoChapters => 'This EPUB has no readable chapters.';

  @override
  String get epubPrevChapter => 'Previous chapter';

  @override
  String get epubNextChapter => 'Next chapter';

  @override
  String epubChapterN(int number) {
    return 'Chapter $number';
  }

  @override
  String get epubErrNoContainer =>
      'Not an EPUB: META-INF/container.xml is missing.';

  @override
  String get epubErrNoOpf => 'Not an EPUB: OPF file not found.';

  @override
  String markdownReadFailed(String error) {
    return 'Could not read the file: $error';
  }

  @override
  String markdownSaved(String name) {
    return 'Saved: $name';
  }

  @override
  String markdownSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get markdownWritingPdf => 'Writing PDF…';

  @override
  String markdownPdfSaved(String name) {
    return 'PDF saved: $name';
  }

  @override
  String get markdownPrint => 'Print';

  @override
  String markdownPdfFailed(String error) {
    return 'Could not write the PDF: $error';
  }

  @override
  String get markdownSaveFirstTitle => 'Save first?';

  @override
  String get markdownUnsavedBody => 'There are unsaved changes.';

  @override
  String get markdownKeepEditing => 'Keep editing';

  @override
  String get markdownDiscard => 'Discard changes';

  @override
  String get markdownSave => 'Save';

  @override
  String get markdownUnsaved => 'Not saved';

  @override
  String get markdownEdit => 'Edit';

  @override
  String get markdownPreview => 'Preview';

  @override
  String get markdownBoth => 'Both';

  @override
  String get markdownMore => 'More';

  @override
  String get markdownSaveAsPdf => 'Save as PDF';

  @override
  String get markdownShareFile => 'Share Markdown file';

  @override
  String get markdownShareAsPdf => 'Share as PDF';

  @override
  String get markdownCopyAll => 'Copy all text';

  @override
  String get markdownHint =>
      'Write here. Markdown: # heading, **bold**, - list, ```mermaid diagram.';

  @override
  String get markdownHeading => 'Heading';

  @override
  String get markdownBold => 'Bold';

  @override
  String get markdownItalic => 'Italic';

  @override
  String get markdownList => 'List';

  @override
  String get markdownTaskList => 'Task list';

  @override
  String get markdownQuote => 'Quote';

  @override
  String get markdownCode => 'Code';

  @override
  String get markdownTable => 'Table';

  @override
  String get markdownTableTemplate =>
      '| Column | Value |\n| --- | --- |\n|  |  |\n';

  @override
  String get markdownMermaid => 'Mermaid diagram';

  @override
  String get markdownMermaidEmpty => 'Empty diagram.';

  @override
  String markdownMermaidUnsupported(String kind) {
    return 'Diagram type \"$kind\" is not drawn yet — supported: graph and flowchart. The source is shown as is.';
  }

  @override
  String get markdownMermaidNoNodes => 'No readable nodes in this diagram.';

  @override
  String get markdownMermaidCannotDraw => 'This diagram cannot be drawn yet.';

  @override
  String get markdownPdfEmpty => '(empty document)';

  @override
  String markdownPdfImageMissing(String path) {
    return '[image not found: $path]';
  }

  @override
  String get markdownEmptyDoc => 'The document is still empty.';

  @override
  String get whiteboardPortrait => 'Portrait';

  @override
  String get whiteboardLandscape => 'Landscape';

  @override
  String get whiteboardBgWhite => 'White';

  @override
  String get whiteboardBgBlack => 'Black';

  @override
  String get whiteboardBgGreen => 'Chalkboard green';

  @override
  String get whiteboardBgCream => 'Cream';

  @override
  String get whiteboardBgNavy => 'Navy';

  @override
  String whiteboardTurned(String orientation) {
    return 'The sheet is now $orientation — the drawing turned with it, nothing was lost.';
  }

  @override
  String whiteboardSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String whiteboardShareFailed(String error) {
    return 'Could not share: $error';
  }

  @override
  String whiteboardSavedAs(String name) {
    return 'Saved as $name';
  }

  @override
  String get notesCannotSaveAsNote => 'Cannot be saved as a note yet';

  @override
  String get notesUnderstood => 'Got it';

  @override
  String get whiteboardSaveNoteFailed => 'Could not save the note';

  @override
  String get whiteboardSavedAsNote => 'Saved as a note';

  @override
  String get whiteboardLeaveTitle => 'Leave this board?';

  @override
  String get whiteboardLeaveBody =>
      'The drawing is not saved and cannot be recovered.';

  @override
  String get whiteboardKeepDrawing => 'Keep drawing';

  @override
  String get whiteboardLeave => 'Leave';

  @override
  String get whiteboardTitle => 'Whiteboard';

  @override
  String whiteboardSheetStatus(int page, int count, String orientation) {
    return 'Sheet $page of $count · $orientation paper';
  }

  @override
  String get whiteboardFreehand => 'Freehand';

  @override
  String whiteboardShape(String shape) {
    return 'Shape: $shape';
  }

  @override
  String get whiteboardFingerOn =>
      'Finger + stylus can draw — tap for stylus only';

  @override
  String get whiteboardStylusOnly =>
      'Stylus only — touching with a hand draws nothing';

  @override
  String get whiteboardBackToWriting => 'Back to writing';

  @override
  String get whiteboardEraserHint => 'Eraser — sweep over strokes';

  @override
  String get whiteboardEraser => 'Eraser';

  @override
  String get whiteboardPortraitTurn => 'Portrait sheet — tap to turn landscape';

  @override
  String get whiteboardLandscapeTurn =>
      'Landscape sheet — tap to turn portrait';

  @override
  String get notesUndo => 'Undo';

  @override
  String get notesRedo => 'Redo';

  @override
  String get whiteboardClearSheet => 'Clear this sheet';

  @override
  String get notesShareAsPdf2 => 'Share as PDF';

  @override
  String get whiteboardSaveAsNote => 'Save as note';

  @override
  String get whiteboardSavePdf => 'Save PDF';

  @override
  String get whiteboardSheet => 'Sheet';

  @override
  String get whiteboardStrokeWidth => 'Stroke width';

  @override
  String get notesPenColor => 'Pen colour';

  @override
  String get markdownMermaidStart => 'Start';

  @override
  String get markdownMermaidDone => 'Done?';

  @override
  String get markdownMermaidYes => 'yes';

  @override
  String get markdownMermaidFinish => 'Finish';

  @override
  String get markdownMermaidNo => 'no';

  @override
  String get notebookHandwritingAlt => 'handwriting';

  @override
  String notebookPageAlt(int number) {
    return 'Page $number';
  }

  @override
  String get notebookErrUnknownContent =>
      'The note file content is not recognised';

  @override
  String notebookErrNewerFormat(int version) {
    return 'This note was written by a newer ReadPaper version (format $version). Update the app first so its content is not damaged.';
  }

  @override
  String get notebookImageMissing => 'image missing';

  @override
  String get notebookDragMove => 'Drag to move';

  @override
  String get notebookDragResize => 'Drag to resize';

  @override
  String get notebookDragRotate => 'Drag to rotate';

  @override
  String get notebookTapSecond => 'Now tap the second item.';

  @override
  String get notebookNewText => 'New text';

  @override
  String get notebookTextHint => 'Type the text';

  @override
  String get notebookNewDiagram => 'New diagram';

  @override
  String get notebookMermaidSource => 'Mermaid source';

  @override
  String get notebookPickImage => 'Choose an image for the note';

  @override
  String get notebookImagePlaced =>
      'Image placed — it can now be moved, resized or deleted.';

  @override
  String get notebookEditText => 'Edit text';

  @override
  String get notebookEditDiagram => 'Edit diagram';

  @override
  String get notebookPickPdf => 'Choose a PDF to insert as sheets';

  @override
  String notebookPreparingSheets(String name) {
    return 'Preparing sheets from $name…';
  }

  @override
  String get notebookPdfNoPages => 'That PDF has no readable pages.';

  @override
  String notebookSheetsInserted(int count, String name) {
    return '$count sheets inserted from $name.';
  }

  @override
  String notebookInsertPdfFailed(String error) {
    return 'Could not insert the PDF: $error';
  }

  @override
  String notebookMarkdownSaved(String name) {
    return 'Markdown saved: $name';
  }

  @override
  String notebookMarkdownFailed(String error) {
    return 'Could not write Markdown: $error';
  }

  @override
  String get notebookSaveToCollectionFailed =>
      'Could not save to the collection';

  @override
  String get notebookSavedToCollection => 'Added to the note collection';

  @override
  String get notebookUnsavedBody => 'There is unsaved writing.';

  @override
  String get notebookKeepWriting => 'Keep writing';

  @override
  String get notebookDiscard => 'Discard';

  @override
  String notebookStatus(
    int page,
    int count,
    String paper,
    String orientation,
    String tool,
  ) {
    return 'Sheet $page of $count · $paper $orientation · tool: $tool';
  }

  @override
  String get notebookUnsavedSuffix => ' · not saved';

  @override
  String get notebookZoomOut => 'Zoom out';

  @override
  String get notebookZoomIn => 'Zoom in';

  @override
  String get notebookFit => 'Fit to screen — reset zoom';

  @override
  String get notebookSaveAndShare => 'Save and share';

  @override
  String get notebookSaveAsMarkdown => 'Save as Markdown';

  @override
  String get notebookSaveToNoteCollection => 'Save to note collection';

  @override
  String get notebookGuideLines => 'Sheet guide lines';

  @override
  String get notebookPlaceText => 'text';

  @override
  String get notebookPlaceImage => 'image';

  @override
  String get notebookPlaceDiagram => 'diagram';

  @override
  String notebookTapToPlace(String what) {
    return 'Tap the sheet to place the $what.';
  }

  @override
  String get notebookTapFirstThenSecond =>
      'Tap the first item, then the second.';

  @override
  String notebookPickedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0 selected';
  }

  @override
  String get notebookRelease => 'Deselect';

  @override
  String notebookPaperChanged(String paper, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Paper is now $paper. $_temp0 are now outside the paper.';
  }

  @override
  String notebookTurned(String orientation) {
    return 'The sheet is now $orientation — its content turned with it, nothing went past the edge.';
  }

  @override
  String notebookIdleTool(String tool) {
    return 'The tool is now \"$tool\" — choose the pen icon to draw.';
  }

  @override
  String get notebookToolPen => 'Pen';

  @override
  String get notebookToolEraseStroke => 'Erase stroke';

  @override
  String get notebookToolErasePart => 'Erase part';

  @override
  String get notebookToolSelect => 'Select';

  @override
  String get notebookToolConnectTwo => 'Connect two items';

  @override
  String get notebookToolText => 'Text';

  @override
  String get notebookToolDiagram => 'Diagram';

  @override
  String get notebookToolImage => 'Image';

  @override
  String get notebookComponentColor => 'Item colour';

  @override
  String get notebookPenWidth => 'Pen width';

  @override
  String get notebookEraserSize => 'Eraser size';

  @override
  String notebookWidthValue(String value) {
    return 'Width $value';
  }

  @override
  String notebookEraserValue(String value) {
    return 'Eraser $value';
  }

  @override
  String get notebookOpacity => 'Opacity';

  @override
  String notebookPaperSize(String paper) {
    return 'Paper size: $paper';
  }

  @override
  String get notebookPortraitTap => 'Portrait paper — tap for landscape';

  @override
  String get notebookLandscapeTap => 'Landscape paper — tap for portrait';

  @override
  String get notebookToolShape => 'Shape';

  @override
  String get notebookToolConnect => 'Connect';

  @override
  String get notebookFingerOn =>
      'Finger and stylus both draw. Tap for stylus only — the finger then only pans and zooms.';

  @override
  String get notebookStylusOnly =>
      'The stylus draws, the finger pans and zooms. Tap to let the finger draw again.';

  @override
  String get notebookFingerChip => 'Finger + stylus';

  @override
  String get notebookStylusChip => 'Stylus only';

  @override
  String get notebookPrevSheet => 'Previous sheet';

  @override
  String get notebookNextSheet => 'Next sheet';

  @override
  String get notebookNewSheet => 'New blank sheet';

  @override
  String get notebookInsertPdfSheet => 'Insert PDF pages as sheets';

  @override
  String get notebookDeleteSheet => 'Delete this sheet';

  @override
  String get whiteboardErrPngEncode => 'PNG encoding failed';

  @override
  String get whiteboardErrPixels => 'Could not read the pixels';

  @override
  String notesUpTo(String name) {
    return 'Back to $name';
  }

  @override
  String notesSubcollectionSummary(int notes, int subs) {
    String _temp0 = intl.Intl.pluralLogic(
      notes,
      locale: localeName,
      other: '$notes notes',
      one: '1 note',
      zero: 'empty',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subs,
      locale: localeName,
      other: ' · $subs sub-collections',
      one: ' · 1 sub-collection',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String officeUnreadable(String error) {
    return 'This document can\'t be read: $error';
  }

  @override
  String get officeEmpty => 'The document is empty.';

  @override
  String get officeTextSmaller => 'Smaller text';

  @override
  String get officeTextLarger => 'Larger text';

  @override
  String get officeOpenExact =>
      'Exact view — convert to PDF with LibreOffice, then search, mark up, and present it';

  @override
  String officeConvertFailed(String error) {
    return 'LibreOffice couldn\'t convert it to PDF: $error';
  }

  @override
  String get officeTextOnly =>
      'Old Office format: only its text is shown here. Open it in an Office app for the full layout.';

  @override
  String get officeTextOnlyWithExact =>
      'Old Office format: only its text is shown here. The PDF button above shows it exactly, via LibreOffice.';

  @override
  String officeSlideN(int number) {
    return 'Slide $number';
  }

  @override
  String get officeSpeakerNotes => 'Speaker notes';

  @override
  String get officePlay => 'Play presentation';

  @override
  String get officeOpenAsPdf => 'Open as PDF — present, reading mode, mark up';

  @override
  String get officeSaveAsPdf => 'Save as PDF…';

  @override
  String get officeMakingPdf => 'Making the PDF…';

  @override
  String officeMakingPdfSlides(int done, int total) {
    return 'Making the PDF… slide $done of $total';
  }

  @override
  String get officePdfSaved => 'PDF saved.';

  @override
  String get officePdfNotSaved => 'PDF not saved.';

  @override
  String officePdfFailed(String error) {
    return 'Couldn\'t make the PDF: $error';
  }

  @override
  String get presenterAudienceWaiting => 'Waiting for the presenter…';

  @override
  String presenterSlideOf(int page, int total) {
    return 'Slide $page of $total';
  }

  @override
  String get presenterResetTimer => 'Elapsed time — tap to restart from zero';

  @override
  String get presenterNextSlide => 'Next slide';

  @override
  String get presenterLastSlide => 'This is the last slide';

  @override
  String get presenterNotes => 'Presenter notes (visible only here)';

  @override
  String get presenterNotesHint => 'Write notes for this slide…';

  @override
  String get presenterBlank => 'Black screen';

  @override
  String get presenterFullSlide => 'Full slide';

  @override
  String get presenterStopAudience => 'Close audience screen';

  @override
  String get presenterOpenAudience =>
      'Show on another screen (second monitor / projector)';

  @override
  String get presenterShowPanel => 'Show presenter panel';

  @override
  String get presenterNoExternalDisplay =>
      'No external display. Connect a monitor/projector (HDMI, USB-C) or cast the screen, then try again.';

  @override
  String get presenterAudienceOpened =>
      'Audience screen opened — press F11 in that window if it is not full screen yet';

  @override
  String get presenterAudienceClosed => 'Audience screen closed';

  @override
  String presenterNotesSaveFailed(String error) {
    return 'Presenter notes could not be saved: $error';
  }

  @override
  String presenterNotesChanged(String title) {
    return 'Presenter notes: $title';
  }

  @override
  String get presenterPointer => 'Pointer';

  @override
  String get presenterPointerTrail => 'Pointer trail';

  @override
  String get presenterTrailOff => 'No trail';

  @override
  String presenterTrailSeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get readerStylusOnlyOn => 'Stylus only: a resting hand will not draw.';

  @override
  String get readerStylusOnlyOff => 'Both finger and stylus can draw.';

  @override
  String get readerCopyNotAllowed => 'This document does not allow copying';

  @override
  String get readerNothingSelected =>
      'No text selected — long-press right on a word';

  @override
  String get readerEraserOn => 'Eraser on — swipe over the ink';

  @override
  String get readerBackToWriting => 'Back to writing';

  @override
  String get readerEraserTooltip => 'Eraser — swipe over the wrong strokes';

  @override
  String get readerEraser => 'Eraser';

  @override
  String get readerBackToPreviousColor => 'Back to the previous colour';

  @override
  String get readerWhiteInk => 'White ink — covers strokes';

  @override
  String get readerUndoEraseInk => 'erasing ink';

  @override
  String get readerUndoEraseStroke => 'erasing a stroke';

  @override
  String get readerEraserMissed => 'The eraser touched no ink';

  @override
  String get readerRedoStroke => 'Redo stroke';

  @override
  String get readerNothingToRedo => 'Nothing to redo';

  @override
  String get readerTapToPlaceSignature =>
      'Tap the page where the signature goes';

  @override
  String get readerCannotOverwriteAttachment =>
      'A library attachment cannot be overwritten — choose another name';

  @override
  String get readerPreparingPdf => 'Preparing PDF…';

  @override
  String get readerSavePdf => 'Save PDF';

  @override
  String get readerNotSaved => 'Not saved';

  @override
  String get readerNoLibraryOpen => 'No library is open in this app yet.';

  @override
  String get readerUnsavedNotIncluded =>
      'Unsaved annotations are not included. Save the PDF first if needed.';

  @override
  String get readerAddToCollectionTitle => 'Add to collection';

  @override
  String get readerNoCollection => 'No collection';

  @override
  String get readerNoCollectionHint =>
      'into the library, not into any collection';

  @override
  String get readerNewCollectionEllipsis => 'New collection…';

  @override
  String get readerNewCollectionHint => 'created and used right away';

  @override
  String get readerCreateCollectionFailed => 'Could not create the collection';

  @override
  String get readerDocumentTitle => 'Document title';

  @override
  String get readerCancel => 'Cancel';

  @override
  String get readerAdd => 'Add';

  @override
  String get readerAddingToLibrary => 'Adding to the library…';

  @override
  String get readerAddFailed => 'Could not add';

  @override
  String get readerNewCollection => 'New collection';

  @override
  String get readerCollectionName => 'Collection name';

  @override
  String get readerCollectionNameHelper =>
      'Written to collections.json, synced to GitHub';

  @override
  String get readerCreate => 'Create';

  @override
  String get readerReadingPageText => 'Reading page text…';

  @override
  String get readerPrintWithoutLatest =>
      'Print without the latest annotations?';

  @override
  String get readerPrintAsIs => 'Print as is';

  @override
  String get readerAddBlankPages => 'Add blank pages';

  @override
  String get readerPdfSavedAsImages =>
      'This PDF cannot be written directly; its pages are saved as images.';

  @override
  String get readerPreparingFile => 'Preparing file…';

  @override
  String get readerNothingSaved => 'Nothing was saved';

  @override
  String get readerSaveAnnotatedCopy => 'Save annotated copy';

  @override
  String get readerSaveChangesFirst => 'Save changes first?';

  @override
  String get readerUnsavedStrokes =>
      'There are unsaved strokes. If you leave now, they will be lost.';

  @override
  String get readerLeaveWithoutSaving => 'Leave without saving';

  @override
  String get readerSaveEllipsis => 'Save…';

  @override
  String get readerSave => 'Save';

  @override
  String get readerMarking => 'Marking';

  @override
  String get readerMark => 'Mark';

  @override
  String get readerTapToPlaceNote =>
      'Tap the page to place a note (tap again to cancel)';

  @override
  String get readerPlaceNote => 'Place a note on the page';

  @override
  String get readerDoneDrawing => 'Done drawing';

  @override
  String get readerDrawOnPage => 'Write or draw on the page';

  @override
  String get readerTapToPlaceText =>
      'Tap the page to place text (tap again to cancel)';

  @override
  String get readerFillText => 'Type text on the page — for filling in forms';

  @override
  String get readerKeepScreenOnActive => 'Screen stays on — tap to turn off';

  @override
  String get readerKeepScreenOn => 'Keep the screen on while reading';

  @override
  String get readerKeepScreenOnEnabled =>
      'The screen will stay on while reading';

  @override
  String get readerKeepScreenOnDisabled =>
      'The screen will turn off by itself again';

  @override
  String get readerPresent => 'Present — one page, full screen';

  @override
  String get readerNothingToUndo => 'Nothing to undo yet';

  @override
  String get readerNothingToRedoYet => 'Nothing to redo yet';

  @override
  String get readerSignature => 'Signature';

  @override
  String get readerSaveAndShare => 'Save and share';

  @override
  String get readerAddToCollectionMenu => 'Add to collection…';

  @override
  String get readerAddToCollectionMenuHint =>
      'goes into the library and is synced';

  @override
  String get readerPrintMenu => 'Print…';

  @override
  String get readerPrintMenuHint => 'to a printer, or save as PDF';

  @override
  String get readerToMarkdown => 'Convert to Markdown';

  @override
  String get readerToMarkdownHint => 'its text becomes an editable document';

  @override
  String get readerToNotebook => 'Make a notebook';

  @override
  String get readerToNotebookHint =>
      'its pages become backgrounds you can edit';

  @override
  String get readerBlankPagesMenuHint =>
      'whiteboard at the end of the document';

  @override
  String get readerSaveMenuHintNew =>
      'choose a name and place; the original stays safe';

  @override
  String get readerSaveAsMenu => 'Save as…';

  @override
  String get readerSaveAsMenuHint => 'another name or place';

  @override
  String get readerExportPagesMenu => 'Export pages…';

  @override
  String get readerExportPagesMenuHint => 'PDF, PNG or JPG';

  @override
  String get readerShare => 'Share';

  @override
  String get readerShareHint => 'chat, email or another app';

  @override
  String get readerStylusOnlyTooltip =>
      'Stylus only — touches from your hand do not draw';

  @override
  String get readerFingerAndStylusTooltip =>
      'Finger + stylus can draw — tap for stylus only';

  @override
  String get readerAddBlankSheet => 'Add a blank sheet';

  @override
  String get readerReadMode => 'Reading mode — hide all bars';

  @override
  String get readerSaveAnnotatedCopyFormats =>
      'Save annotated copy (PNG, JPG, PDF)';

  @override
  String get readerZoomOut => 'Zoom out';

  @override
  String get readerZoomIn => 'Zoom in';

  @override
  String get readerAnnotationPanel => 'Annotation panel';

  @override
  String get readerGotIt => 'Got it';

  @override
  String get readerDone => 'Done';

  @override
  String get readerUndoLastStroke => 'Undo the last stroke';

  @override
  String get readerDiscardStrokes => 'Discard all unsaved strokes';

  @override
  String get readerTapWhereNote => 'Tap a spot on the page to place the note.';

  @override
  String get readerPreviousPage => 'Previous page';

  @override
  String get readerNextPage => 'Next page';

  @override
  String get readerFingerAndStylusShort =>
      'Finger + stylus — tap for stylus only';

  @override
  String get readerFitPage => 'Fit one page to the screen';

  @override
  String get readerScribble => 'Scribble on the page';

  @override
  String get readerUndo => 'Undo';

  @override
  String get readerSaveChooseTooltip => 'Save… (choose a name and place)';

  @override
  String get readerAddScribbleSheet => 'Add a blank sheet to scribble on';

  @override
  String get readerExitPresent => 'Leave presentation mode';

  @override
  String get readerExitReadMode => 'Leave reading mode';

  @override
  String get readerClipboardFallback => 'ReadPaper annotation';

  @override
  String get readerClipboardEmpty =>
      'The clipboard holds no image or annotation';

  @override
  String get readerPasteImageUnsupported =>
      'Pasting images is not supported on this device yet — use \"Choose an image file\"';

  @override
  String get readerClipboardNoImage =>
      'The clipboard holds no image. In a browser: right-click the image → Copy image.';

  @override
  String get readerChooseImage => 'Choose an image';

  @override
  String get readerPreparingImage => 'Preparing image…';

  @override
  String get readerNotAnImage =>
      'The clipboard or file is not a readable image';

  @override
  String get readerUndoPasteImage => 'pasting an image';

  @override
  String get readerInsertImage => 'Insert image';

  @override
  String get readerPasteImage => 'Paste image from the clipboard';

  @override
  String get readerPasteImageHint =>
      'e.g. \"Copy image\" in a browser — Ctrl+V';

  @override
  String get readerChooseImageFile => 'Choose an image file…';

  @override
  String get readerAnnotationCopied =>
      'Annotation copied — go to the target page, then Paste';

  @override
  String get readerUndoCut => 'cutting an annotation';

  @override
  String get readerAnnotationCut =>
      'Annotation cut — go to the target page, then Paste';

  @override
  String get readerUndoPaste => 'pasting an annotation';

  @override
  String get readerMoveToPage => 'Move to page';

  @override
  String get readerMove => 'Move';

  @override
  String get readerCopy => 'Copy';

  @override
  String get readerCut => 'Cut';

  @override
  String get readerToPage => 'To page…';

  @override
  String get readerPaste => 'Paste';

  @override
  String get readerDeselect => 'Deselect';

  @override
  String get readerClearClipboard => 'Clear clipboard';

  @override
  String get readerDropOnPage => 'Drop it on a page to move it';

  @override
  String get readerOutsidePage => 'Outside the page';

  @override
  String get readerUndoReshape => 'reshaping an annotation';

  @override
  String get readerUndoMove => 'moving an annotation';

  @override
  String get readerHighlight => 'Highlight';

  @override
  String get readerHighlightComment => 'Highlight + comment';

  @override
  String get readerUnderline => 'Underline';

  @override
  String get readerText => 'Text';

  @override
  String get readerComment => 'Comment';

  @override
  String get readerTextHint => 'What goes on the page…';

  @override
  String get readerCommentHint => 'A note about this part…';

  @override
  String get readerUndoEdit => 'editing an annotation';

  @override
  String get readerDeleteAnnotationQuestion => 'Delete annotation?';

  @override
  String get readerDelete => 'Delete';

  @override
  String get readerUndoDelete => 'deleting an annotation';

  @override
  String get readerAnnotationDeleted => 'Annotation deleted';

  @override
  String get readerDeleteFailed => 'Could not delete the annotation';

  @override
  String get readerSaveImageFailed => 'Could not save the image';

  @override
  String get readerSaved => 'Saved';

  @override
  String get readerChangesSaved => 'Changes saved';

  @override
  String get readerAddedNotSaved => 'Added — not yet saved to the file';

  @override
  String get readerAdded => 'Added';

  @override
  String get readerSaveAnnotationFailed => 'Could not save the annotation';

  @override
  String get readerEditNote => 'Edit note';

  @override
  String get readerCloseNote => 'Close note';

  @override
  String get readerDragToMove => 'Drag to move';

  @override
  String get readerDragToResize => 'Drag to resize';

  @override
  String get readerDragToRotate => 'Drag to rotate';

  @override
  String get readerEditCommentColor => 'Edit comment / colour';

  @override
  String get readerDpiScreen => 'Screen (72 dpi)';

  @override
  String get readerDpiGood => 'Good (144 dpi)';

  @override
  String get readerDpiPrint => 'Print (288 dpi)';

  @override
  String get readerFormat => 'Format';

  @override
  String get readerDensity => 'Resolution';

  @override
  String get readerWholeDocument => 'Whole document';

  @override
  String get readerJumpToPage => 'Jump to page';

  @override
  String get readerPage => 'Page';

  @override
  String get readerGo => 'Go';

  @override
  String get readerTableOfContents => 'Table of contents';

  @override
  String get readerNoTableOfContents => 'This file has no table of contents.';

  @override
  String get readerUntitled => '(untitled)';

  @override
  String get readerTintNormal => 'Normal';

  @override
  String get readerTintSepia => 'Sepia';

  @override
  String get readerTintDim => 'Dim';

  @override
  String get readerTintInvert => 'Invert colours';

  @override
  String get readerSaveInFolder => 'Save in folder';

  @override
  String get readerFileNameTaken => 'File name already in use';

  @override
  String get readerNo => 'No';

  @override
  String get readerYesOverwrite => 'Yes, overwrite';

  @override
  String get readerSaveAs => 'Save as';

  @override
  String get readerFileName => 'File name';

  @override
  String get readerSaveIn => 'Save in';

  @override
  String get readerChooseOtherFolder => 'Choose another folder…';

  @override
  String get readerOtherPlace => 'Elsewhere…';

  @override
  String get readerClearSelection => 'Clear selection';

  @override
  String get readerSignatureHint =>
      'Write here, then tap the page to place it.';

  @override
  String get readerClear => 'Clear';

  @override
  String get readerUse => 'Use';

  @override
  String get readerErrSourceMissing => 'The source file does not exist';

  @override
  String get readerErrPdfUnreadable => 'The PDF cannot be read';

  @override
  String get readerErrPageCopy => 'The original page cannot be copied';

  @override
  String get readerErrBlankPage => 'The blank page cannot be created';

  @override
  String get readerErrFileMissing => 'The file does not exist';

  @override
  String get readerErrPdfWrite => 'Writing the PDF failed';

  @override
  String get readerErrPdfOpen => 'The PDF cannot be opened';

  @override
  String get readerErrPageRewrite => 'Rewriting the page content failed';

  @override
  String get readerErrRender => 'Rendering the page failed';

  @override
  String get readerErrPngEncode => 'Encoding the PNG failed';

  @override
  String get readerErrPixels => 'Reading the pixels failed';

  @override
  String readerLoadAnnotationsFailed(String error) {
    return 'Could not read annotations: $error';
  }

  @override
  String readerNoteAnnotationsUnreadable(String error) {
    return 'This note\'s annotations cannot be read: $error';
  }

  @override
  String readerCharactersCopied(int count) {
    return '$count characters copied';
  }

  @override
  String readerRedoStep(String step) {
    return 'Redo: $step';
  }

  @override
  String readerPageColorInverted(String color) {
    return 'Page colour: $color — marker colours are inverted too';
  }

  @override
  String readerPageColor(String color) {
    return 'Page colour: $color';
  }

  @override
  String readerResumedAtPage(int page) {
    return 'Resumed at page $page';
  }

  @override
  String readerUndone(String step) {
    return 'Undone: $step';
  }

  @override
  String readerRedone(String step) {
    return 'Redone: $step';
  }

  @override
  String readerOriginalFolder(String folder) {
    return 'The original file\'s folder ($folder)';
  }

  @override
  String readerSavedFile(String name, String size) {
    return 'Saved: $name ($size)';
  }

  @override
  String readerSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String readerPdfSaved(String size) {
    return 'PDF saved ($size)';
  }

  @override
  String get readerAddToCollectionExplain =>
      'The file is copied into the library, given a Zotero item and committed — so it is synced to GitHub.';

  @override
  String readerNewSubcollectionIn(String name) {
    return 'New sub-collection inside $name';
  }

  @override
  String readerAddedButAnnotationsFailed(String error) {
    return 'Added to the library, but copying its annotations failed: $error';
  }

  @override
  String readerAddedAs(String key) {
    return 'Added to the library as $key';
  }

  @override
  String readerAddedWithAnnotations(String key, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annotations',
      one: '1 annotation',
    );
    return 'Added to the library as $key with $_temp0 — readable in Zotero too once sent';
  }

  @override
  String readerPreparingNotebook(String title) {
    return 'Preparing a notebook from $title…';
  }

  @override
  String readerNotebookFailed(String error) {
    return 'Could not create the notebook: $error';
  }

  @override
  String readerSubcollectionIn(String name) {
    return 'Sub-collection in $name';
  }

  @override
  String get readerNoTextLayer =>
      'This PDF has no text layer — probably a scan. Only its title came out.';

  @override
  String readerMarkdownFailed(String error) {
    return 'Could not convert to Markdown: $error';
  }

  @override
  String get readerPrintExplain =>
      'Some annotations are not part of the page yet, so they will not be printed. Save the PDF first if they need to be included.';

  @override
  String readerPrintFailed(String error) {
    return 'Could not print: $error';
  }

  @override
  String get readerBlankPagesExplain =>
      'The size of the first page. The original file is not touched — only a working copy changes, until you save it.';

  @override
  String readerPagesAfter(int count, int page) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0 after page $page';
  }

  @override
  String readerPagesAtEnd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0 at the end of the document';
  }

  @override
  String readerBlankPagesAdded(int count) {
    return '$count blank pages added at the end — save through the share menu';
  }

  @override
  String readerBlankPagesInserted(int count, int page) {
    return '$count blank pages inserted after page $page — save through the share menu';
  }

  @override
  String readerAddPagesFailed(String error) {
    return 'Could not add pages: $error';
  }

  @override
  String readerShareFailed(String error) {
    return 'Could not share: $error';
  }

  @override
  String readerSavePage(int page) {
    return 'Save page $page';
  }

  @override
  String readerSaveImageError(String error) {
    return 'Could not save the image: $error';
  }

  @override
  String readerFilesSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 saved';
  }

  @override
  String readerPreparingPdfPages(int count) {
    return 'Preparing a $count-page PDF…';
  }

  @override
  String readerPdfFailed(String error) {
    return 'Could not create the PDF: $error';
  }

  @override
  String readerUnsavedStandalone(String title) {
    return 'The ink and annotations in $title are not saved to a file yet. If you leave now, they will all be lost.';
  }

  @override
  String readerUndoStep(String step) {
    return 'Undo: $step';
  }

  @override
  String readerSaveMenuHintTo(String name) {
    return 'to $name';
  }

  @override
  String readerStatus(int count, int page) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annotations',
      one: '1 annotation',
    );
    return '$_temp0 · page $page';
  }

  @override
  String readerStatusOf(int count, int page, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annotations',
      one: '1 annotation',
    );
    return '$_temp0 · page $page of $total';
  }

  @override
  String get readerCoachMark =>
      'To mark: tap \"Mark\", pick a colour, then swipe a finger over the text — it is coloured as soon as you lift your finger. To copy: leave \"Mark\" off, long-press the text, then choose Copy. For a note: tap the note icon, then tap the page.';

  @override
  String readerMarkingBannerTouch(String color) {
    return 'Swipe a finger over the text — lift it and it is marked $color. Page scrolling and copying are off; tap Done to go back.';
  }

  @override
  String readerMarkingBannerMouse(String color) {
    return 'Drag the mouse over the text — release the button and it is marked $color. Page scrolling and copying are off; press Done to go back.';
  }

  @override
  String get readerEraserBanner =>
      'Eraser: swipe over the wrong ink — every stroke it touches is removed whole.';

  @override
  String get readerPenBanner =>
      'Draw freely on the page with a finger or stylus.';

  @override
  String readerPenPending(int count, int page) {
    return '$count strokes on page $page — saved when you press Done.';
  }

  @override
  String readerSaveTo(String name) {
    return 'Save to $name';
  }

  @override
  String readerPageNumber(int page) {
    return 'Page $page';
  }

  @override
  String readerImagePasted(int page) {
    return 'Image pasted on page $page — drag its corner to resize';
  }

  @override
  String readerPastedOnPage(int page) {
    return 'Pasted on page $page — drag to move it';
  }

  @override
  String readerPageRange(int count) {
    return 'Page 1 to $count';
  }

  @override
  String readerNoSuchPage(int page, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return 'There is no page $page — this document has $_temp0';
  }

  @override
  String readerUndoMoveToPage(int page) {
    return 'moving an annotation to page $page';
  }

  @override
  String readerMovedToPage(int page) {
    return 'Moved to page $page';
  }

  @override
  String readerPasteOnPage(int page) {
    return 'Paste on page $page';
  }

  @override
  String readerTextOnPage(int page) {
    return 'Text on page $page';
  }

  @override
  String readerNoteOnPage(int page) {
    return 'Note on page $page';
  }

  @override
  String readerAnnotationOnPage(String page) {
    return 'Annotation, page $page';
  }

  @override
  String readerUndoAdd(String type) {
    return 'adding $type';
  }

  @override
  String readerNoteBubbleTitle(String page) {
    return 'Note · p. $page';
  }

  @override
  String readerHighlightColor(String color) {
    return 'Highlight colour: $color';
  }

  @override
  String readerStrokeWidth(String width) {
    return 'Stroke width: $width';
  }

  @override
  String readerOnlyPage(int page) {
    return 'Only page $page';
  }

  @override
  String readerOnePdfPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return 'One PDF with $_temp0';
  }

  @override
  String readerFilesOnePerPage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0, one per page';
  }

  @override
  String get readerExportExplain =>
      'Highlights, underlines and ink are drawn in. The original file is not touched.';

  @override
  String get readerExportPdfImages =>
      'Pages are stored as images inside the PDF, so the text cannot be searched or copied in that copy.';

  @override
  String readerExportLarge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0 at this resolution will take a while and quite some storage.';
  }

  @override
  String get readerNoAnnotationsYet =>
      'No annotations yet.\n\nSelect text on the page, then choose Highlight or Highlight + comment.';

  @override
  String readerPageShort(String page) {
    return 'p. $page';
  }

  @override
  String readerPageMustBeBetween(int count) {
    return 'The page must be between 1 and $count';
  }

  @override
  String readerOfPages(int count) {
    return 'of $count';
  }

  @override
  String readerOpenPage(int page) {
    return 'Open page $page';
  }

  @override
  String readerOverwriteOriginal(String name) {
    return '$name is the file that is open. Overwriting it loses the original, and the ink is merged into the pages.\n\nOverwrite the original?';
  }

  @override
  String readerOverwriteExisting(String name) {
    return '$name already exists in this folder.\n\nReplace it with the new one?';
  }

  @override
  String get readerSaveAsExplain =>
      'The open file is not touched. After this, Save writes to this new file.';

  @override
  String readerOutsideZoteroPalette(String name) {
    return '$name (outside Zotero\'s palette)';
  }

  @override
  String readerErrCannotRead(String path) {
    return 'Cannot be read: $path';
  }

  @override
  String readerErrPageSize(String size) {
    return 'Unreasonable page size: $size';
  }

  @override
  String workspaceSwitchRepoCount(int count) {
    return 'Switch repository ($count available)';
  }

  @override
  String workspaceAddAnotherRepo(String remote) {
    return '$remote — add another repository';
  }

  @override
  String get workspaceManageRepos => 'Manage repositories…';

  @override
  String get workspaceSwitchLibrary => 'Switch library';

  @override
  String get workspaceFetchingLibrary => 'Fetching…';

  @override
  String get workspaceFetchLibrary => 'Fetch library';

  @override
  String syncPullCount(int count) {
    return 'Pull $count new commits';
  }

  @override
  String get syncPull => 'Pull changes';

  @override
  String get syncMenu => 'Sync';

  @override
  String get syncCheck => 'Check for changes';

  @override
  String get syncSend => 'Send changes';

  @override
  String get syncDetails => 'Sync details';

  @override
  String get syncCheckRemote => 'Check the remote for changes';

  @override
  String get syncSendToGitHub => 'Send changes to GitHub';

  @override
  String get syncBusyWait => 'A sync is running; wait until it finishes.';

  @override
  String syncBusyPhaseWait(String phase) {
    return '$phase Wait until it finishes.';
  }

  @override
  String get syncNothingToSend => 'Nothing to send.';

  @override
  String syncTooltipBranch(String branch) {
    return 'Branch: $branch';
  }

  @override
  String syncTooltipLastCommit(String subject) {
    return 'Last commit: $subject';
  }

  @override
  String syncTooltipLastSync(String time) {
    return 'Last sync: $time';
  }

  @override
  String get workspaceReadingLibrary => 'Reading the library from disk…';

  @override
  String get syncCommitMessage => 'Commit message';

  @override
  String get syncCommitAndSend => 'Commit & send';

  @override
  String get workspaceCancel => 'Cancel';

  @override
  String get workspaceAccessSshHttps => 'over SSH or HTTPS';

  @override
  String get workspaceAccessToken => 'with a GitHub token';

  @override
  String get workspaceNoRepoTitle => 'No repository yet';

  @override
  String workspaceNoRepoBody(String access) {
    return 'ReadPaper reads Zotero libraries synced to GitHub by the zotero-github-sync plugin. Add a repository ($access) to start reading, highlighting and commenting on papers.';
  }

  @override
  String get workspaceAddRepo => 'Add repository';

  @override
  String workspaceFetchLibraryNamed(String name) {
    return 'Fetch library \"$name\"';
  }

  @override
  String workspaceCloneNamed(String name) {
    return 'Clone \"$name\"';
  }

  @override
  String get workspaceResumeNote =>
      'The previous download was interrupted. Resuming only fetches the files not saved yet.';

  @override
  String get workspaceLazyNote =>
      'The library metadata is downloaded now; PDFs follow when each paper is opened.';

  @override
  String workspaceWillSaveAt(String path) {
    return 'Will be saved in $path';
  }

  @override
  String get workspaceCheckConnection => 'Check connection';

  @override
  String get workspaceEditProfile => 'Edit profile';

  @override
  String get workspaceDownloading => 'Downloading…';

  @override
  String get workspaceCloning => 'Cloning…';

  @override
  String get workspaceResume => 'Resume';

  @override
  String get workspaceFetchNow => 'Fetch now';

  @override
  String get workspaceCloneNow => 'Clone now';

  @override
  String get workspaceLibraryUnreadableTitle => 'Library could not be read';

  @override
  String get workspaceLibraryUnreadableBody =>
      'The repository is on this device but no Zotero structure was found (collections.json and an items/ folder). Make sure it is an export of the Zotero GitHub Sync plugin, then pull the latest changes.';

  @override
  String get workspaceReload => 'Reload';

  @override
  String get workspacePull => 'Pull';

  @override
  String get workspaceRepository => 'Repository';

  @override
  String get syncLfsMissing =>
      'git-lfs is not installed; large attachments stay as pointers';

  @override
  String get syncLfsPullAll => 'Download all LFS files';

  @override
  String syncBranchLine(String branch) {
    return 'branch $branch';
  }

  @override
  String get syncTabChanges => 'Changes';

  @override
  String get syncTabHistory => 'History';

  @override
  String get syncTabLog => 'Git log';

  @override
  String get syncRecloneNotice =>
      'This local copy still holds every attachment. Fetching it again downloads only metadata; PDFs follow when each paper is opened.';

  @override
  String get syncReclone => 'Fetch again';

  @override
  String get syncRecloneTitle => 'Fetch the local copy again?';

  @override
  String get syncRecloneBody =>
      'The local folder is deleted and fetched again without attachments. Annotations already sent to GitHub are safe; unsent ones would be lost, so this is refused while changes are pending.';

  @override
  String get syncNoLocalChanges => 'No local changes.';

  @override
  String get syncNoCommits => 'No commits yet.';

  @override
  String get syncNoGitOutput => 'No git output yet.';

  @override
  String get workspaceManageReposTooltip => 'Manage repositories';

  @override
  String get workspaceReadingLibraryShort => 'Reading the library…';

  @override
  String get workspaceFillToken => 'Enter token';

  @override
  String get workspaceRetry => 'Try again';

  @override
  String get workspaceClose => 'Close';

  @override
  String workspaceTransferRepoNotFetched(String name) {
    return 'Repository \"$name\" has not been fetched to this device. Open it once and fetch its library, then try again.';
  }

  @override
  String workspaceTransferLibraryMissing(String name) {
    return 'The library in \"$name\" is not on this device yet. Open that repository once and fetch its library, then try again.';
  }

  @override
  String get workspaceTransferTitle => 'To another repository';

  @override
  String get workspaceTransferNoOthers =>
      'There is no other repository yet. Add one first in the Repositories settings.';

  @override
  String get workspaceTransferChange => 'Change';

  @override
  String get workspaceTransferMove => 'Move';

  @override
  String get workspaceTransferCopy => 'Copy';

  @override
  String get workspaceTransferMoveNote =>
      'Removed from this repository once the copy is complete at the destination.';

  @override
  String get workspaceTransferCopyNote =>
      'This one stays; the destination gets a copy.';

  @override
  String get workspaceTransferNotesRoot => 'Notes root';

  @override
  String get workspaceTransferNotesUnfiled => 'Notes, no collection';

  @override
  String get workspaceTransferLibraryRoot => 'Library root';

  @override
  String get workspaceTransferUnfiled => 'No collection';

  @override
  String get workspaceComputingSize => 'computing size…';

  @override
  String get syncPhaseCounting => 'Counting objects';

  @override
  String get syncPhaseCompressing => 'Compressing objects';

  @override
  String get syncPhaseReceiving => 'Receiving objects';

  @override
  String get syncPhaseResolving => 'Resolving deltas';

  @override
  String get syncPhaseWritingFiles => 'Writing files';

  @override
  String get syncPhaseFiltering => 'Downloading large files';

  @override
  String get syncPhaseLfs => 'Downloading LFS files';

  @override
  String get syncPhaseSending => 'Sending objects';

  @override
  String get syncPhaseEnumerating => 'Enumerating objects';

  @override
  String get workspaceStatsNotFetched => 'not fetched to this device yet';

  @override
  String workspaceStatsItems(String count) {
    return 'items: $count';
  }

  @override
  String workspaceStatsCollections(String count) {
    return 'collections: $count';
  }

  @override
  String workspaceStatsAttachments(String size) {
    return 'attachments $size';
  }

  @override
  String workspaceStatsUnsent(int count) {
    return '$count unsent';
  }

  @override
  String workspaceStatsBehind(int count) {
    return '$count new on GitHub';
  }

  @override
  String get syncPhaseCloning => 'Cloning the repository…';

  @override
  String get syncPhaseFetching => 'Checking for changes…';

  @override
  String get syncPhasePulling => 'Pulling changes…';

  @override
  String get syncPhaseCommitting => 'Saving changes…';

  @override
  String get syncPhasePushing => 'Sending changes…';

  @override
  String get syncChangeNew => 'new';

  @override
  String get syncChangeAdded => 'added';

  @override
  String get syncChangeModified => 'modified';

  @override
  String get syncChangeDeleted => 'deleted';

  @override
  String get syncChangeRenamed => 'moved';

  @override
  String get syncStatusNotCloned => 'Not cloned';

  @override
  String syncStatusLocalChanges(int count) {
    return '$count local changes';
  }

  @override
  String syncStatusAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commits',
      one: '1 commit',
    );
    return '$_temp0 not pushed';
  }

  @override
  String syncStatusBehind(int count) {
    return '$count new commits on the remote';
  }

  @override
  String get syncStatusInSync => 'In sync';

  @override
  String get workspaceErrNoZoteroExport =>
      'No Zotero export found in this repository. Expected structure: zotero/<library>/collections.json';

  @override
  String workspaceErrReadLibrary(String error) {
    return 'Could not read the library: $error';
  }

  @override
  String get workspaceErrNoRemoteUrl => 'This profile has no remote URL yet.';

  @override
  String get workspaceErrUnsentBeforeReclone =>
      'There are changes not yet sent to GitHub. Send them first, then fetch again.';

  @override
  String workspaceErrDeleteOldCopy(String error) {
    return 'Could not delete the old copy: $error';
  }

  @override
  String get workspaceErrAnnotationNoLibrary =>
      'Annotation not saved: no library is open in the app.';

  @override
  String get workspaceErrAnnotationUnchanged =>
      'Annotation not saved: the item file did not change.';

  @override
  String workspaceErrAnnotationSave(String error) {
    return 'Annotation not saved: $error';
  }

  @override
  String get workspaceErrAnnotationDeleteNoLibrary =>
      'Annotation not deleted: no library is open.';

  @override
  String workspaceErrAnnotationDelete(String error) {
    return 'Annotation not deleted: $error';
  }

  @override
  String get workspaceErrPictureNoRepo =>
      'Image not saved: no repository is open.';

  @override
  String workspaceErrPictureSave(String error) {
    return 'Image not saved: $error';
  }

  @override
  String workspaceErrPictureDelete(String error) {
    return 'Image not deleted: $error';
  }

  @override
  String get workspaceErrNoLibraryForFile =>
      'No library is open to hold this file.';

  @override
  String workspaceErrAddToLibrary(String error) {
    return 'Could not add to the library: $error';
  }

  @override
  String get workspaceErrNoLibraryForFolder =>
      'No library is open to hold this folder.';

  @override
  String workspaceErrImportStopped(String error) {
    return 'Folder import stopped: $error';
  }

  @override
  String get workspaceErrNoLibrary => 'No library is open.';

  @override
  String workspaceErrCreateCollection(String error) {
    return 'Could not create the collection: $error';
  }

  @override
  String get workspaceErrSameRepo => 'The destination is the same repository.';

  @override
  String workspaceErrMoveFailed(String error) {
    return 'Could not move: $error';
  }

  @override
  String workspaceErrCopyFailed(String error) {
    return 'Could not copy: $error';
  }

  @override
  String get workspaceErrCollectionGone => 'The collection no longer exists.';

  @override
  String workspaceErrMissingAttachments(int count) {
    return '$count attachments are not on this device yet — not downloaded, or still Git LFS pointers. Open the paper once so its PDF is downloaded (on desktop: LFS pull), then try again. Nothing was moved: without its PDF the paper would arrive empty.';
  }

  @override
  String workspaceErrChangeCollection(String error) {
    return 'Could not change the collection: $error';
  }

  @override
  String get workspaceErrTargetCollectionGone =>
      'The destination collection no longer exists.';

  @override
  String workspaceErrMove(String error) {
    return 'Could not move: $error';
  }

  @override
  String workspaceErrDelete(String error) {
    return 'Could not delete: $error';
  }

  @override
  String workspaceErrDeleteClone(String error) {
    return 'Could not delete the local clone: $error';
  }

  @override
  String get syncGitCliLabel => 'git (system CLI)';

  @override
  String get syncFileAlreadyLocal => 'The file is already on this device';

  @override
  String get syncFileLocationUnknown => 'Unrecognised file location.';

  @override
  String syncDownloadingFile(String name) {
    return 'Downloading $name…';
  }

  @override
  String get syncFileDownloaded => 'File downloaded';

  @override
  String get syncFileNotInRepo => 'The file is not in this repository.';

  @override
  String get syncDownloadingLfs => 'Downloading large file (Git LFS)…';

  @override
  String get syncRemoteReachable => 'Remote reachable';

  @override
  String syncConnected(String count) {
    return 'Connected · $count branches on the remote';
  }

  @override
  String get syncTargetNotEmpty =>
      'The destination folder already has files. Delete them or choose another location.';

  @override
  String get syncCloned => 'Repository cloned';

  @override
  String get syncPreparingMetadata => 'Preparing metadata files…';

  @override
  String get syncMetadataReady => 'Metadata ready';

  @override
  String get syncRepoReadyLazy =>
      'Repository ready. Attachments download when each paper is opened.';

  @override
  String get syncFetchDone => 'Fetch done';

  @override
  String get syncPullDone => 'Pull done';

  @override
  String syncInterruptedNotAborted(String operation, String backup) {
    return 'The previous sync stopped in the middle of a $operation and could not be undone automatically. Its state was backed up at $backup.';
  }

  @override
  String syncInterruptedRecovered(String backup) {
    return 'The sync that stopped midway was recovered (backup: $backup)';
  }

  @override
  String syncConflict(String detail) {
    return 'Changes here and on GitHub conflict and cannot be merged automatically. Nothing is lost: local changes stay in their commit$detail.';
  }

  @override
  String get syncRebasedOnGitHub =>
      'Local changes were applied on top of the GitHub version';

  @override
  String syncAutoMerged(String files) {
    return 'Merged automatically: $files';
  }

  @override
  String syncGitHubCopies(String files) {
    return 'GitHub version saved as $files';
  }

  @override
  String get syncNothingToCommit => 'Nothing to commit';

  @override
  String get syncCommitCreated => 'Commit created';

  @override
  String get syncPushDone => 'Push done';

  @override
  String get syncLfsSkipped => 'git-lfs is not installed, skipped';

  @override
  String get syncLfsDownloaded => 'LFS files downloaded';

  @override
  String get syncRemoteUpdated => 'Remote updated';

  @override
  String syncGitCannotRun(String error) {
    return 'git could not be run: $error';
  }

  @override
  String get syncErrSshRejected =>
      'SSH refused: GitHub did not accept the key. Check the key path in the profile.';

  @override
  String get syncErrHttpsAuth =>
      'HTTPS authentication failed: the token is empty or invalid.';

  @override
  String get syncErrRepoNotFound => 'Repository not found, or no access to it.';

  @override
  String get syncErrMergeConflict =>
      'There is a conflict merging changes. Resolve it in the local repository.';

  @override
  String get syncErrNoNetwork => 'No network available.';

  @override
  String syncErrGitFailed(int code) {
    return 'git failed (code $code)';
  }

  @override
  String get syncUnknownUser => '(unknown)';

  @override
  String get syncErrTreeTooLarge =>
      'The repository file list is too large for the GitHub API to read at once.';

  @override
  String syncErrBlobTooLarge(String size) {
    return 'The file is $size MB, above the 100 MB limit the GitHub API accepts for one file. Send it with regular git on a computer, or keep the attachment outside the repository.';
  }

  @override
  String syncErrConnectionLost(int attempts) {
    return 'The connection to GitHub dropped and did not recover after $attempts attempts. The download can resume where it stopped.';
  }

  @override
  String get syncErrTokenRejected =>
      'GitHub rejected the token. Check the token in the repository profile.';

  @override
  String get syncErrQuota =>
      'The GitHub request quota is used up. Try again once it recovers (about an hour), or use a token with a larger quota.';

  @override
  String get syncErrSlowDown =>
      'GitHub asked to slow down because too many files were sent in a row. Wait a few minutes, then send again.';

  @override
  String get syncErrForbidden =>
      'Access denied. The token needs \"Contents: read and write\" permission for this repository.';

  @override
  String get syncErrNotFound =>
      'Repository or file not found. For a private repository, the token must have access to it.';

  @override
  String get syncErrBranchMoved =>
      'The branch on GitHub has changed. Pull changes first, then send again.';

  @override
  String get syncErrRejectedNoReason =>
      'GitHub rejected this change (422) without giving a reason.';

  @override
  String syncErrRejected(String reason) {
    return 'GitHub rejected this change: $reason';
  }

  @override
  String syncErrStatus(int code) {
    return 'GitHub replied with code $code.';
  }

  @override
  String syncErrStatusReason(int code, String reason) {
    return 'GitHub replied with code $code: $reason';
  }

  @override
  String get syncGitHubApiLabel => 'GitHub API';

  @override
  String get syncErrRepoUrlUnknown => 'Unrecognised repository URL.';

  @override
  String get syncErrTokenMissing => 'No GitHub token has been entered.';

  @override
  String syncConnectedAs(String login, String slug, String head, String quota) {
    return 'Connected as $login · $slug at $head$quota';
  }

  @override
  String syncQuotaLeft(String count) {
    return ' · $count requests left';
  }

  @override
  String get syncErrNotGitHubUrl =>
      'The repository URL is not recognised as a GitHub repository.';

  @override
  String get syncErrAndroidNeedsToken =>
      'On Android, sync uses a GitHub token. Enter the token in the repository profile.';

  @override
  String syncReadingBranch(String branch, String slug) {
    return 'Reading branch $branch on $slug…';
  }

  @override
  String syncMirrorReady(int files, int attachments) {
    return 'Mirror ready: $files metadata files, $attachments attachments waiting to download when opened';
  }

  @override
  String syncPartialSaved(String error, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$error $_temp0 are already saved — press \"Resume\" to continue.';
  }

  @override
  String get syncUpToDate => 'Already up to date';

  @override
  String syncBehindWaiting(int count) {
    return '$count new commits waiting on GitHub';
  }

  @override
  String syncComparing(String head) {
    return 'Comparing with commit $head…';
  }

  @override
  String get syncNoMetadataChanges => 'No metadata changes';

  @override
  String syncPullUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Pull done: $_temp0 updated';
  }

  @override
  String get syncLfsUnsupportedAndroid =>
      'Git LFS files are not supported by Android sync yet.';

  @override
  String syncAttachmentsSkippedOnly(int count) {
    return '$count attachments skipped; nothing else to send';
  }

  @override
  String syncReadyToSend(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 ready to send';
  }

  @override
  String syncReadyToSendSkipped(int count, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 ready to send; $skipped attachments skipped (send them with git on a computer)';
  }

  @override
  String get syncNothingToSendShort => 'Nothing to send';

  @override
  String get syncErrRemoteNewer =>
      'GitHub already has newer commits. Pull changes first, then send again.';

  @override
  String get syncErrQueueOnlyAttachments =>
      'The queue only holds attachments; nothing can be sent this way.';

  @override
  String get syncUploading => 'Uploading files';

  @override
  String syncSentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Sent: $_temp0';
  }

  @override
  String syncErrAttachmentNotInRepo(String path) {
    return 'Attachment not in the repository: $path';
  }

  @override
  String get syncAllPdfsPresent => 'All PDFs are already on this device';

  @override
  String syncAllPdfsPresentLfs(int count) {
    return 'All PDFs are present; $count LFS attachments must be fetched from a computer';
  }

  @override
  String syncDownloadingPdfOf(int current, int total, String name) {
    return 'Downloading PDF $current of $total: $name';
  }

  @override
  String syncPdfsDownloadedOffline(int count) {
    return '$count PDFs downloaded for offline reading';
  }

  @override
  String syncMirrorAtCommit(String sha) {
    return 'Mirror at commit $sha';
  }

  @override
  String get syncErrNotMirrored =>
      'The repository has not been mirrored on this device.';

  @override
  String syncRejectedMore(int count) {
    return ' and $count more';
  }

  @override
  String get syncNothingSent => 'Nothing was sent';

  @override
  String syncSentFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 sent';
  }

  @override
  String syncRejectedSummary(
    String head,
    int count,
    String names,
    String more,
    String reason,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$head; $_temp0 were rejected by GitHub and are still waiting: $names$more. $reason';
  }

  @override
  String get syncResumingMetadata => 'Resuming the metadata download';

  @override
  String get syncDownloadingMetadata => 'Downloading metadata';

  @override
  String syncErrCorruptDownload(String name) {
    return 'A file was corrupted while downloading: $name. Run it again to re-download the failed part.';
  }

  @override
  String get syncErrGitHubUrlUnknown => 'Unrecognised GitHub repository URL.';

  @override
  String get syncErrTokenMissingProfile =>
      'No GitHub token has been entered in the repository profile.';

  @override
  String get syncInstallGitWindows =>
      'Git for Windows was not found. Install it from git-scm.com, or in PowerShell: winget install --id Git.Git -e — then press Try again.';

  @override
  String get syncInstallGitMac =>
      'git was not found. Run in Terminal: xcode-select --install.';

  @override
  String get syncInstallGitLinux =>
      'git was not found. Install git and git-lfs — CachyOS/Arch: sudo pacman -S git git-lfs; Debian/Ubuntu: sudo apt install git git-lfs.';
}
