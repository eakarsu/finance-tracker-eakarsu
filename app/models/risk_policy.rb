class RiskPolicy < ActiveRecord::Base
  belongs_to :paper_account
  belongs_to :kill_switch_changed_by, class_name: "User", optional: true

  validates :max_gross_exposure, :max_order_notional, :max_daily_loss, :minimum_daily_volume,
    :max_spread_bps, :approval_notional, numericality: { greater_than: 0 }
  validates :stale_after_seconds, numericality: { only_integer: true, greater_than: 0 }

  def activate_kill_switch!(actor:, reason:)
    raise ArgumentError, "operator role required" unless actor.operator?
    raise ArgumentError, "reason is required" if reason.blank?
    update!(kill_switch: true, kill_switch_reason: reason, kill_switch_changed_at: Time.current, kill_switch_changed_by: actor)
  end

  def release_kill_switch!(actor:, reason:)
    raise ArgumentError, "operator role required" unless actor.operator?
    raise ArgumentError, "reason is required" if reason.blank?
    update!(kill_switch: false, kill_switch_reason: reason, kill_switch_changed_at: Time.current, kill_switch_changed_by: actor)
  end
end
