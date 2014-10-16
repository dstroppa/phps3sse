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

  Chef::Log.info("Accessing '#{node['secret']['bucket']}'/'#{node['secret']['object']}' with '#{node['s3']['access_key_id']}' - '#{node['s3']['secret_access_key']}' ")
  s3 = AWS::S3.new(
      :access_key_id => node[:s3][:access_key_id],
      :secret_access_key => node[:s3][:secret_access_key])
  secret = s3.buckets[node[:secret][:bucket]].objects[node[:secret][:object]].read.strip
  Chef::Log.info("The secret is '#{secret}' ")

  file "/etc/chef/encrypted_data_bag_secret" do
    content secret
    owner 'root'
    group 'root'
    mode 0400
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

    rdspwd = Chef::EncryptedDataBagItem.load("rds_secrets", "rdspwd")
    Chef::Log.info("The decrypted user is '#{rdspwd['user']}' ")
    Chef::Log.info("The decrypted password is '#{rdspwd['password']}' ")

    variables(
      :host =>     (deploy[:database][:host] rescue nil),
      :user =>     (rdspwd[:user] rescue nil),
      :password => (rdspwd[:password] rescue nil),
      :db =>       (deploy[:database][:database] rescue nil),
      :table =>    (node[:phpapp][:dbtable] rescue nil)
    )

   only_if do
     File.directory?("#{deploy[:deploy_to]}/current")
   end
  end
end
