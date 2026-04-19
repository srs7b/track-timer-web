import 'package:flutter/material.dart';
import '../models/run_model.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  Run? _pendingAnalysisRun;

  int get currentIndex => _currentIndex;
  Run? get pendingAnalysisRun => _pendingAnalysisRun;

  void setTab(int index, {Run? runToAnalyze}) {
    _currentIndex = index;
    _pendingAnalysisRun = runToAnalyze;
    notifyListeners();
  }

  void clearPendingAnalysis() {
    _pendingAnalysisRun = null;
    // We don't necessarily need to notify here if we just consumed it
  }
}
