require 'rubygems'
require 'sinatra'
require 'yaml'
require 'activerecord'
require 'erubis'
require 'bureaucrat'
require 'bureaucrat/quickfields'
require 'rack-flash'

enable :sessions
use Rack::Flash

ENV['RACK_ENV'] ||= 'development'

ActiveRecord::Base.establish_connection(
  YAML::load(File.open('db/config.yml'))[ENV['RACK_ENV']]
)
ActiveRecord::Base.logger = Logger.new(STDOUT)

class Singer < ActiveRecord::Base; end

class SignupForm < Bureaucrat::Forms::Form
  extend Bureaucrat::Quickfields
  string :first_name
  string :last_name
  email :email
  string :birthdate
  string :phone
  choice :voicepart, [
                       ['', ''],
                       ['s1', 'Soprano I'],
                       ['s2', 'Soprano II'],
                       ['a1', 'Alto I'],
                       ['a2', 'Alto II'],
                       ['t1', 'Tenor I'],
                       ['t2', 'Tenor II'],
                       ['b1', 'Bass I'],
                       ['b2', 'Bass II']
                     ],
          :label => "Voice Part"
  text :comments, :required => false
end

helpers do
  # Rails-like partial handler.
  # Usage:
  #   Render the page once:
  #     partial :foo
  #   Render once for each element in an array, passing in a local variable
  #   named foo:
  #     partial :foo, :collection => @my_foos    
  def partial(template, *args)
    options = args.extract_options!
    options.merge!(:layout => false)
    if collection = options.delete(:collection) then
      collection.inject([]) do |buffer, member|
        buffer << erb(template, options.merge(
                                  :layout => false, 
                                  :locals => {template.to_sym => member}
                                )
                     )
      end.join("\n")
    else
      erb(template, options)
    end
  end
end

get '/' do
  <<-EOS
    <html>
      <head>
        <title>Stadium of Fire Chorus</title>
      </head>
      <body>
        <h1>The Stadium of Fire Chorus</h1>
        <p>We are currently down for maintenance.</p>
        <p>Please return shortly to sign up for the Stadium of Fire Chorus 2010.</p>
        <p>We anticipate rehearsals will begin in Provo around the 15th of June.</p>
        <p>Thanks for your interest!</p>
      </body>
    </html>
  EOS
  erb :index
end

get '/signup' do
  @form = SignupForm.new
  erb :signup
end

post '/do_signup' do
  singer_data = {}
  Singer.column_names.each do |col| 
    val = params.delete(col)
    singer_data[col.to_sym] = val if val
  end
  @form = SignupForm.new(singer_data)
  begin
    b_day = Date.parse(singer_data[:birthdate]) rescue nil
    if b_day.nil? || !(Date.today.year - b_day.year).between?(1, 120)
      @form.errors[:birthdate] = "Needs to be a valid date (including 4-digit year)"
    end
    phone = singer_data[:phone]
    if phone.nil? || !(phone.match(/^[ext\s\d()-.]{7,}$/i))
      @form.errors[:phone] = "Needs to be a valid phone number"
    end
    raise "Invalid form data" if !@form.valid?
    singer_data[:birthdate] = b_day
    singer_data[:status] = "committed"
    Singer.create!(singer_data)
    erb :signup_thanks
  rescue => e
    flash[:error] = <<-EOS
      Something went wrong with your form submission:<br/>
      #{e.to_s}<br/>
      <!--
      #{e.backtrace.join("\n")}
      -->
    EOS
    erb :signup
  end
end

get /\/(\w+)$/ do |tpl|
  erb tpl.to_sym
end

get '/admin/sample' do
  erb :'admin/sample', :layout => :'layout_admin'
end
