import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/sync/data/datasources/git_locator.dart';

void main() {
  group('Windows', () {
    const env = <String, String>{
      'PATH': r'C:\Windows\system32;C:\Windows',
      'ProgramFiles': r'C:\Program Files',
      'LOCALAPPDATA': r'C:\Users\hendri\AppData\Local',
      'USERPROFILE': r'C:\Users\hendri',
    };

    String find(Set<String> present, {List<String> desktop = const <String>[]}) =>
        GitLocator.locate(
          environment: env,
          exists: present.contains,
          listDirs: (dir) => dir.endsWith('GitHubDesktop') ? desktop : const <String>[],
          operatingSystem: 'windows',
          appDir: r'D:\Apps\ReadPaper',
        );

    test('Git for Windows di Program Files, walau tidak ada di PATH', () {
      expect(
        find(<String>{r'C:\Program Files\Git\cmd\git.exe'}),
        r'C:\Program Files\Git\cmd\git.exe',
      );
    });

    test('pemasangan per pengguna dan Scoop', () {
      expect(
        find(<String>{r'C:\Users\hendri\AppData\Local\Programs\Git\cmd\git.exe'}),
        r'C:\Users\hendri\AppData\Local\Programs\Git\cmd\git.exe',
      );
      expect(
        find(<String>{r'C:\Users\hendri\scoop\shims\git.exe'}),
        r'C:\Users\hendri\scoop\shims\git.exe',
      );
    });

    test('git bawaan GitHub Desktop, versi terbaru dulu', () {
      const base = r'C:\Users\hendri\AppData\Local\GitHubDesktop';
      expect(
        find(
          <String>{
            '$base\\app-3.4.1\\resources\\app\\git\\cmd\\git.exe',
            '$base\\app-3.5.0\\resources\\app\\git\\cmd\\git.exe',
          },
          desktop: <String>['$base\\app-3.4.1', '$base\\app-3.5.0', '$base\\packages'],
        ),
        '$base\\app-3.5.0\\resources\\app\\git\\cmd\\git.exe',
      );
    });

    test('MinGit bawaan zip dipakai bila Git for Windows tidak terpasang', () {
      expect(
        GitLocator.locate(
          environment: env,
          exists: (path) => path == r'D:\Apps\ReadPaper\git\cmd\git.exe',
          listDirs: (_) => const <String>[],
          operatingSystem: 'windows',
          appDir: r'D:\Apps\ReadPaper',
        ),
        r'D:\Apps\ReadPaper\git\cmd\git.exe',
      );
    });

    test('tidak ada di mana pun → serahkan ke PATH', () {
      expect(find(const <String>{}), 'git');
    });

    test('pesan pemasangan menyebut winget', () {
      expect(GitLocator.installHint('windows'), contains('winget install --id Git.Git'));
    });
  });

  test('Linux: peluncur dengan PATH pendek tetap menemukan /usr/bin/git', () {
    expect(
      GitLocator.locate(
        environment: const <String, String>{'PATH': '/home/x/.local/bin'},
        exists: (path) => path == '/usr/bin/git',
        operatingSystem: 'linux',
      ),
      '/usr/bin/git',
    );
    expect(GitLocator.installHint('linux'), contains('pacman -S git git-lfs'));
  });
}
