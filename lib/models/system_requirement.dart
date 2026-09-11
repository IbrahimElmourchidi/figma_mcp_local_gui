enum RequirementStatus { met, missing, outdated, checking, error }

class SystemRequirement {
  final String name;
  final String description;
  final RequirementStatus status;
  final String? currentVersion;
  final String? requiredVersion;
  final String? installCommand;
  final String? installUrl;
  final String? guideUrl;

  SystemRequirement({
    required this.name,
    required this.description,
    this.status = RequirementStatus.checking,
    this.currentVersion,
    this.requiredVersion,
    this.installCommand,
    this.installUrl,
    this.guideUrl,
  });

  bool get isMet => status == RequirementStatus.met;
  bool get isMissing => status == RequirementStatus.missing;
  bool get isOutdated => status == RequirementStatus.outdated;
  bool get isChecking => status == RequirementStatus.checking;
  bool get isError => status == RequirementStatus.error;

  SystemRequirement copyWith({
    String? name,
    String? description,
    RequirementStatus? status,
    String? currentVersion,
    String? requiredVersion,
    String? installCommand,
    String? installUrl,
    String? guideUrl,
  }) {
    return SystemRequirement(
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      requiredVersion: requiredVersion ?? this.requiredVersion,
      installCommand: installCommand ?? this.installCommand,
      installUrl: installUrl ?? this.installUrl,
      guideUrl: guideUrl ?? this.guideUrl,
    );
  }
}
