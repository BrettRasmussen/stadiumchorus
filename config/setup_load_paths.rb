# Passenger-specific file to set up environment stuff.

if ENV['MY_RUBY_HOME'] && ENV['MY_RUBY_HOME'].include?('rvm')
  begin
    rvm_path     = File.dirname(File.dirname(ENV['MY_RUBY_HOME']))
    rvm_lib_path = File.join(rvm_path, 'lib')
    $LOAD_PATH.unshift rvm_lib_path
    require 'rvm'
    orig_gem_home = ENV['GEM_HOME'].dup
    RVM.use_from_path! File.dirname(File.dirname(__FILE__))

    # For some reason, RVM.use_from_path! doesn't seem to be finding the gemset
    # reliably from the project's .rvmrc, so here we attempt doing that by hand.
    dot_rvmrc = "#{File.dirname(File.dirname(__FILE__))}/.rvmrc"
    if !ENV['GEM_HOME'].match(/@(\w+)$/) && File.readable?(dot_rvmrc)
      new_gemset = nil
      rvm_id_re = /^rvm\s+([\w|\.]+)@(\w+)/
      File.readlines(dot_rvmrc).each do |line|
        if rvm_match = line.strip.match(rvm_id_re)
          RVM.gemset_use!(rvm_match.to_a[2])
          break
        end
      end
    end
  rescue LoadError
    # RVM is unavailable at this point.
    raise "RVM ruby lib is currently unavailable."
  end
end
