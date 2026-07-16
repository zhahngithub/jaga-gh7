class RequestState {
  const RequestState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  static const idle = RequestState();
  static const loading = RequestState(isLoading: true);

  factory RequestState.error(String message) {
    return RequestState(errorMessage: message);
  }

  factory RequestState.success(String message) {
    return RequestState(successMessage: message);
  }
}
