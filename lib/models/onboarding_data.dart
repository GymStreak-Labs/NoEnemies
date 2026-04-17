import 'conflict_type.dart';

/// Intermediate data model that collects all answers during the 26-screen
/// onboarding flow. Converted into a [UserProfile] at completion.
class OnboardingData {
  String? userName;
  List<int> quizAnswers = []; // indices for Q1-Q6 (0-3)
  String? conflictTarget; // Q7
  String? conflictDuration; // Q8
  List<String> previousAttempts = []; // Q9
  String? conflictStyle; // Q10
  int conflictIntensity = 5; // slider 1-10
  String? preferredCheckInTime; // morning/evening/both
  String? personalIntention; // free text
  bool readyToCommit = true;
  ConflictType? calculatedConflictType;
}
