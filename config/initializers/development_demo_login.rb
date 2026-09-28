Rails.application.config.after_initialize do
  enabled = ENV.fetch("ENABLE_DEMO_CREDENTIAL_AUTOFILL", "true") == "true"
  next unless Rails.env.development? && enabled

  email = ENV["DEMO_EMAIL"].presence || ENV["PROVISION_ADMIN_EMAIL"].presence || ENV["ADMIN_EMAIL"].presence
  password = ENV["DEMO_PASSWORD"].presence || ENV["PROVISION_ADMIN_PASSWORD"].presence || ENV["ADMIN_PASSWORD"].presence
  next if email.blank? || password.blank?
  next unless ActiveRecord::Base.connection.data_source_exists?("users")

  user = User.find_or_initialize_by(email: email.downcase.strip)
  user.first_name ||= "Demo"
  user.last_name ||= "Operator"
  user.risk_role = "operator"
  user.password = password
  user.password_confirmation = password
  user.save!
end
