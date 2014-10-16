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

  s3 = AWS::S3.new(
      :access_key_id => 'AKIAIQTW7PHF2SMDIOCA',
      :secret_access_key => '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')
  secret = s3.buckets['stroppad-chef-data-bags'].objects['encrypted_data_bag_secret'].read.strip

  file "/etc/chef/encrypted_data_bag_secret" do
    content secret
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
