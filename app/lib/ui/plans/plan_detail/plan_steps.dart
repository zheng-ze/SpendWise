// MARK: - Steps

sealed class PlanDetailStep {}

class PlanEditRequested extends PlanDetailStep {}

class PlanDeleteRequested extends PlanDetailStep {}
