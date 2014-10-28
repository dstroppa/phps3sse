require 'rubygems' 
require 'aws-sdk'

node[:deploy].each do |app_name, deploy|

  script "install_composer" do
    interpreter "bash"
    user "root"
    cwd "#{deploy[:deploy_to]}/current"
    code <<-EOH
    curl -sS https://getcomposer.org/installer | php
    php composer.phar install --no-dev
    EOH
  end

  template "#{deploy[:deploy_to]}/current/db-connect.php" do
    source "db-connect.php.erb"
    mode 0660
    group deploy[:group]

    if platform?("ubuntu")
      owner "www-data"
    elsif platform?("amazon")   
      owner "apache"
    end

    s3 = AWS::S3.new(
      :access_key_id => node[:s3][:access_key_id],
      :secret_access_key => node[:s3][:secret_access_key])
    secret = s3.buckets[node[:secret][:bucket]].objects[node[:secret][:object]].read.strip

    rdscredentials = Chef::EncryptedDataBagItem.load("rdscredentials", "rdscredentials", secret)
    Chef::Log.info("The decrypted user is '#{rdscredentials['user']}' ")
    Chef::Log.info("The decrypted password is '#{rdscredentials['password']}' ")

    variables(
      :host =>     (deploy[:database][:host] rescue nil),
      :user =>     (rdscredentials[:user] rescue nil),
      :password => (rdscredentials[:password] rescue nil),
      :db =>       (deploy[:database][:database] rescue nil),
      :table =>    (node[:phpapp][:dbtable] rescue nil)
    )

   only_if do
     File.directory?("#{deploy[:deploy_to]}/current")
   end
  end
end
