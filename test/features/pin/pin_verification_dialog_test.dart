import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jaga/features/map/presentation/widgets/pin_verification_dialog.dart';
import 'package:jaga/features/pin/application/pin_providers.dart';
import 'package:jaga/features/pin/data/models/pin_models.dart';
import 'package:jaga/features/pin/data/repositories/pin_repository.dart';

void main() {
  testWidgets('PIN benar mengembalikan sukses dan aksi berjalan sekali', (
    tester,
  ) async {
    final verification = Completer<bool>();
    final repository = _FakePinRepository(
      verify: (_, _) => verification.future,
    );
    var protectedActionCalls = 0;

    await tester.pumpWidget(
      _testApp(
        repository: repository,
        onProtectedAction: () => protectedActionCalls++,
      ),
    );
    await tester.tap(find.text('Buka verifikasi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4827');
    await tester.pump();

    await tester.tap(find.text('Verifikasi'));
    await tester.tap(find.text('Verifikasi'));
    expect(repository.verifyCalls, 1);

    verification.complete(true);
    await tester.pumpAndSettle();

    expect(protectedActionCalls, 1);
    expect(repository.lastVerifiedUid, 'uid-current');
    expect(find.byType(PinVerificationDialog), findsNothing);
  });

  testWidgets('PIN salah tidak menutup dialog atau menjalankan aksi', (
    tester,
  ) async {
    final repository = _FakePinRepository(
      verify: (_, _) async => throw const PinFailure(PinErrorCode.incorrectPin),
    );
    var protectedActionCalls = 0;

    await tester.pumpWidget(
      _testApp(
        repository: repository,
        onProtectedAction: () => protectedActionCalls++,
      ),
    );
    await tester.tap(find.text('Buka verifikasi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4826');
    await tester.pump();
    await tester.tap(find.text('Verifikasi'));
    await tester.pumpAndSettle();

    expect(find.text('PIN yang kamu masukkan salah.'), findsOneWidget);
    expect(find.byType(PinVerificationDialog), findsOneWidget);
    expect(protectedActionCalls, 0);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('Kembali membatalkan tanpa menjalankan aksi', (tester) async {
    final repository = _FakePinRepository(verify: (_, _) async => true);
    var protectedActionCalls = 0;

    await tester.pumpWidget(
      _testApp(
        repository: repository,
        onProtectedAction: () => protectedActionCalls++,
      ),
    );
    await tester.tap(find.text('Buka verifikasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    expect(protectedActionCalls, 0);
    expect(repository.verifyCalls, 0);
    expect(find.byType(PinVerificationDialog), findsNothing);
  });

  testWidgets('lockout repository menonaktifkan verifikasi', (tester) async {
    final repository = _FakePinRepository(
      verify: (_, _) async => true,
      attempts: PinAttemptState(
        failedAttempts: 5,
        lockoutUntil: DateTime.now().add(const Duration(seconds: 30)),
      ),
    );

    await tester.pumpWidget(
      _testApp(repository: repository, onProtectedAction: () {}),
    );
    await tester.tap(find.text('Buka verifikasi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Terlalu banyak percobaan.'), findsOneWidget);
    final verifyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verifikasi'),
    );
    expect(verifyButton.onPressed, isNull);

    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
    expect(repository.verifyCalls, 0);
  });
}

Widget _testApp({
  required PinRepository repository,
  required VoidCallback onProtectedAction,
}) {
  return ProviderScope(
    overrides: [
      currentPinUserIdProvider.overrideWithValue('uid-current'),
      pinRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      home: _DialogHarness(onProtectedAction: onProtectedAction),
    ),
  );
}

class _DialogHarness extends StatelessWidget {
  const _DialogHarness({required this.onProtectedAction});

  final VoidCallback onProtectedAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final verified = await showPinVerificationDialog(context);
            if (!verified) return;
            onProtectedAction();
          },
          child: const Text('Buka verifikasi'),
        ),
      ),
    );
  }
}

class _FakePinRepository implements PinRepository {
  _FakePinRepository({
    required this.verify,
    this.attempts = const PinAttemptState(failedAttempts: 0),
  });

  final Future<bool> Function(String uid, String pin) verify;
  final PinAttemptState attempts;
  int verifyCalls = 0;
  String? lastVerifiedUid;

  @override
  Future<PinAttemptState> getAttemptState(String uid) async => attempts;

  @override
  Future<bool> verifyPin(String uid, String pin) {
    verifyCalls++;
    lastVerifiedUid = uid;
    return verify(uid, pin);
  }

  @override
  Future<void> clearPin(String uid) => throw UnimplementedError();

  @override
  Future<bool> hasPin(String uid) => throw UnimplementedError();

  @override
  Future<void> setInitialPin(String uid, String pin) =>
      throw UnimplementedError();
}
