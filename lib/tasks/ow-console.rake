namespace :ow do

  require 'momentum/opsworks'
  require 'momentum/tasks'

  desc "Open a Rails console on the given remote OpsWorks stack (uses AWS_USER as SSH username or falls back to local username)."
  task :console, [:to, :env, :aws_id, :aws_secret] do |t, args|
    require_credentials!(args)
    ow = Momentum::OpsWorks.client(args[:aws_id], args[:aws_secret])
    name = stack_name(args[:to])
    stack = Momentum::OpsWorks.get_stack(ow, name)
    layer = ow.describe_layers(stack_id: stack[:stack_id])[:layers].detect { |l| l[:shortname] == Momentum.config[:rails_console_layer] }
    instance = Momentum::OpsWorks.get_online_instances(ow, layer_id: layer[:layer_id]).sample
    raise "No online #{Momentum.config[:rails_console_layer]} instances found for #{name} stack!" unless instance

    $stderr.puts "Starting remote console... (use Ctrl-D to exit cleanly)"
    sh [
      'ssh -t',
      (['-i', ENV['AWS_PUBLICKEY']] if ENV['AWS_PUBLICKEY']),
      (['-l', ENV['AWS_USER']] if ENV['AWS_USER']),
      instance[:public_dns],
      "'sudo su deploy --session-command=\"cd /srv/www/#{Momentum.config[:app_base_name]}/current && RAILS_ENV=#{args[:env] || args[:to]} bundle exec rails console\"'"
    ].compact.flatten.join(' ')
  end

end