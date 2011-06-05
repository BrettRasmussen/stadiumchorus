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


# Represents a member of the choir.
class Singer < ActiveRecord::Base
  def age
    age = Date.today.year - birthdate.year
    age -= 1 if Date.today.yday < birthdate.yday
    age
  end

  def to_contact
    contact_attrs = {}
    %w[first_name last_name email birthdate
    phone comments voicepart].each do |attr|
      contact_attrs[attr] = self.attributes[attr]
    end
    if self.attributes.has_key?("voicepart_id")
      voiceparts = {1=>'s1', 2=>'s2', 3=>'a1', 4=>'a2',
                    5=>'t1', 6=>'t2', 7=>'b1', 8=>'b2'}
      contact_attrs["voicepart"] = voiceparts[self.voicepart_id]
    end
    if self.attributes.has_key?("age")
      b_day = (Time.parse("7/4/2009") - self[:age].years).to_date
      contact_attrs["birthdate"] = b_day
    end
    contact_attrs["status"] = "interested"
    Contact.create!(contact_attrs)
  end
end

# Represents someone on the contact list, usually a past member of the choir.
class Contact < ActiveRecord::Base
  validates_uniqueness_of :email
  def age
    age = Date.today.year - birthdate.year
    age -= 1 if Date.today.yday < birthdate.yday
    age
  end
end

# Represents an admin user.
class User < ActiveRecord::Base
  def self.authenticate(username, password)
    User.find(:first, :conditions => {:username => username, :password => password})
  end
end

# All of the voiceparts, with nickname for storing in the database and display
# name for showing to the end users.
VOICEPARTS = [
  {:value => 's1', :display => 'Soprano I'},
  {:value => 's2', :display => 'Soprano II'},
  {:value => 'a1', :display => 'Alto I'},
  {:value => 'a2', :display => 'Alto II'},
  {:value => 't1', :display => 'Tenor I'},
  {:value => 't2', :display => 'Tenor II'},
  {:value => 'b1', :display => 'Bass I'},
  {:value => 'b2', :display => 'Bass II'}
]

# Encapsulates the necessary data to ask for on the signup form.
class SignupForm < Bureaucrat::Forms::Form
  extend Bureaucrat::Quickfields
  string :first_name
  string :last_name
  email :email
  string :birthdate
  string :phone
  choice :voicepart,
         [['','']] + VOICEPARTS.collect {|vp| [vp[:value], vp[:display]]},
         :label => "Voice Part"
  text :comments, :required => false
end

# Encapsulates the necessary data to ask for on the login page.
class LoginForm < Bureaucrat::Forms::Form
  extend Bureaucrat::Quickfields
  string :username
  password :password
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

# Shows the main index page containing all the details.  Comment out the "erb
# :index" line in order to show the "down for maintenance" message.
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

# Show the signup form.
get '/signup' do
  @form = SignupForm.new
  erb :signup
end

# Handles the post from the signup form, making sure the provided data is valid.
# If something goes wrong, shows the form again but with error messages.
post '/do_signup' do
  singer_data = {}
  Singer.column_names.each do |col| 
    val = params.delete(col)
    singer_data[col.to_sym] = val if val
  end
  @form = SignupForm.new(singer_data)
  output = begin
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
    singer_data[:status] = "interested"
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
  if ENV['RACK_ENV'] == 'production'
    if fork.nil?
      %x{scp -P 202 db/production.sl3 twoedge.dyndns.org:wk/stadiumchorus/stadiumchorus/db/} rescue nil
    end
  end
  output
end

# Shows the main admin page with the list of all the active singers.
get /\/admin\/?$/ do
  require_login
  @singers = Singer.find(:all, :conditions => "status = 'committed'")
  @singers = @singers.sort_by {|s| s.last_name.downcase + s.first_name.downcase}
  calculate_email_dupes
  @part_counts = Hash.new(0)
  @singers.each {|s| @part_counts[s.voicepart] += 1}
  @voiceparts = VOICEPARTS
  erb :'admin/index', :layout => :'admin/layout'
end

# Shows the login form for the admin section.
get '/admin/login' do
  @form = LoginForm.new
  @redirect_url = params["redirect_url"]
  erb :'admin/login', :layout => :'admin/layout'
end

# Handles the post from the admin login page.
post '/admin/login' do
  user = User.authenticate(params['username'], params['password'])
  if user
    session["user"] = user.id
    if params["redirect_url"]
      redirect params["redirect_url"]
    else
      redirect '/admin'
    end
  else
    flash[:error] = "Invalid login"
    erb :'admin/login', :layout => 'admin/layout'
  end
end

# Logs the admin user out.
get '/admin/logout' do
  session.delete "user"
  redirect '/admin/login'
end

# Shows a comma-separated list of the email addresses of all members currently
# active in the choir.
get '/admin/email_list' do
  require_login
  sql = "select distinct(email) from singers where status = 'committed'"
  @email_addresses = ActiveRecord::Base.connection.select_values(sql)
  erb :'admin/email_list', :layout => :'admin/layout'
end

# Shows a comma-separated list of the email addresses of all people in the
# contact list, excluding those currently in the list of singers.
get '/admin/contact_list' do
  require_login
  sql = "select distinct(email) from contacts
         where email not in (select distinct(email) from singers)"
  @email_addresses = ActiveRecord::Base.connection.select_values(sql)
  erb :'admin/contact_list', :layout => :'admin/layout'
end

# Shows any duplicate entries in the singers table, with a side-by-side
# comparison of what data is different between the entries.
get '/admin/duplicates' do
  require_login
  @singers = Singer.find(:all, :conditions => {:status => 'committed'})
  calculate_email_dupes
  erb :'admin/duplicates', :layout => :'admin/layout'
end

# Shows any requested page there's a matching template for.
get /\/(\w+)$/ do |tpl|
  erb tpl.to_sym
end

# Redirects to the login page if the requested page requires an admin session
# and the user doesn't have one.
def require_login
  redirect "/admin/login?redirect_url=#{request.fullpath}" if session["user"].nil?
end

# Finds any duplicates by email address and, if it finds any, removes them from
# the @singers list and populates the @email_dupes list for use by the
# templates.
def calculate_email_dupes
  @email_dupes = {}
  if !@singers.empty?
    @singers.each do |s|
      email = s.email.strip
      @email_dupes[email] ||= {}
      @email_dupes[email][:objects] ||= []
      @email_dupes[email][:objects] << s
    end
    @email_dupes.delete_if {|k,v| v[:objects].size < 2}

    @attrs = @singers[0].attributes.keys - %w[created_at updated_at]

    @email_dupes.each do |email,val|
      differences = {}
      @attrs.each do |attr|
        values = val[:objects].collect {|so| eval("so.#{attr}")}
        differences[attr] = values if values.uniq.size > 1
      end
      @email_dupes[email][:differences] = differences
    end
    @email_dupes.delete_if {|k,v| v[:differences].has_key?('first_name')}
  end
end
