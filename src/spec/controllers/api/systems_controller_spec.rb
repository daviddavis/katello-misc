#
# Copyright 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require 'spec_helper.rb'
include OrchestrationHelper

describe Api::SystemsController do
  include LoginHelperMethods
  include LocaleHelperMethods
  include SystemHelperMethods
  include AuthorizationHelperMethods

  let(:facts) { {"distribution.name" => "Fedora"} }
  let(:uuid) { '1234' }
  let(:package_profile) {
    [{"epoch" => 0, "name" => "im-chooser", "arch" => "x86_64", "version" => "1.4.0", "vendor" => "Fedora Project", "release" => "1.fc14"},
     {"epoch" => 0, "name" => "maven-enforcer-api", "arch" => "noarch", "version" => "1.0", "vendor" => "Fedora Project", "release" => "0.1.b2.fc14"},
     {"epoch" => 0, "name" => "ppp", "arch" => "x86_64", "version" => "2.4.5", "vendor" => "Fedora Project", "release" => "12.fc14"},
     {"epoch" => 0, "name" => "pulseaudio-module-bluetooth", "arch" => "x86_64", "version" => "0.9.21", "vendor" => "Fedora Project", "release" => "7.fc14"},
     {"epoch" => 0, "name" => "dbus-cxx-glibmm", "arch" => "x86_64", "version" => "0.7.0", "vendor" => "Fedora Project", "release" => "2.fc14.1"},
     {"epoch" => 0, "name" => "twolame-libs", "arch" => "x86_64", "version" => "0.3.12", "vendor" => "RPM Fusion", "release" => "4.fc11"},
     {"epoch" => 0, "name" => "gtk-vnc", "arch" => "x86_64", "version" => "0.4.2", "vendor" => "Fedora Project", "release" => "4.fc14"}]
  }
  let(:installed_products) { [{"productId"=>"69", "productName"=>"Red Hat Enterprise Linux Server"}] }
  let(:sorted) { package_profile.sort {|a,b| a["name"].downcase <=> b["name"].downcase} }

  let(:user_with_read_permissions) { user_with_permissions { |u| u.can(:read_systems, :organizations, nil, @organization) } }
  let(:user_without_read_permissions) { user_without_permissions }
  let(:user_with_create_permissions) { user_with_permissions { |u| u.can([:register_systems], :environments, @environment_1.id, @organization) } }
  let(:user_without_create_permissions) { user_with_permissions { |u| u.can(:read_systems, :organizations, nil, @organization) } }
  let(:user_with_update_permissions) { user_with_permissions { |u| u.can([:read_systems, :update_systems], :organizations, nil, @organization) } }
  let(:user_without_update_permissions) { user_without_permissions }
  let(:user_with_destroy_permissions) { user_with_permissions { |u| u.can([:delete_systems], :organizations, nil, @organization) } }
  let(:user_without_destroy_permissions) { user_with_permissions { |u| u.can([:read_systems], :organizations, nil, @organization) } }

  before (:each) do
    login_user
    set_default_locale
    disable_org_orchestration

    Candlepin::Consumer.stub!(:create).and_return({:uuid => uuid, :owner => {:key => uuid}})
    Candlepin::Consumer.stub!(:update).and_return(true)
    
    Pulp::Consumer.stub!(:create).and_return({:uuid => uuid, :owner => {:key => uuid}})
    Pulp::Consumer.stub!(:update).and_return(true)

    @organization = Organization.create!(:name => 'test_org', :cp_key => 'test_org')
    @environment_1 = KTEnvironment.create!(:name => 'test_1', :prior => @organization.locker.id, :organization => @organization)
  end

  describe "create a system" do

    let(:action) { :create }
    let(:req) { post :create, :owner => @organization.name, :name => 'test', :cp_type => 'system', :facts => facts }
    let(:authorized_user) { user_with_create_permissions }
    let(:unauthorized_user) { user_without_create_permissions }
    it_should_behave_like "protected action"

    it "requires either environment_id, owner, or organization_id to be specified" do
      post :create
      response.code.should == "400"
    end

    it "sets insatalled products to the consumer" do
        System.should_receive(:create!).with(hash_including(:environment => @environment_1, :cp_type => 'system', :installedProducts => installed_products, :name => 'test')).once.and_return({})
        post :create, :organization_id => @organization.name, :name => 'test', :cp_type => 'system', :installedProducts => installed_products
    end

    context "in organization with one environment" do
      it "requires either organization_id" do
        System.should_receive(:create!).with(hash_including(:environment => @environment_1, :cp_type => 'system', :facts => facts, :name => 'test')).once.and_return({})
        post :create, :organization_id => @organization.name, :name => 'test', :cp_type => 'system', :facts => facts
      end

      it "or requires owner (key)" do
        System.should_receive(:create!).with(hash_including(:environment => @environment_1, :cp_type => 'system', :facts => facts, :name => 'test')).once.and_return({})
        post :create, :owner => @organization.name, :name => 'test', :cp_type => 'system', :facts => facts
      end
    end

    context "in organization with multiple environments" do
      before(:each) do
        @environment_2 = KTEnvironment.new(:name => 'test_2', :prior => @environment_1, :organization => @organization)
        @environment_2.save!
      end

      it "requires environment id" do
        System.should_receive(:create!).with(hash_including(:environment => @environment_1, :cp_type => 'system', :facts => facts, :name => 'test')).once.and_return({})
        post :create, :environment_id => @environment_1.id, :name => 'test', :cp_type => 'system', :facts => facts
      end

      it "fails if no environment_id was specified" do
        post :create, :organization_id => @organization.cp_key
        response.code.should == "400"
      end
    end

    context "when activation keys are provided" do

      before(:each) do
        @system_template = SystemTemplate.create!(:name => "system template", :environment => @environment_1)
        @activation_key_1 = ActivationKey.create!(:environment => @environment_1,
                                                  :organization => @organization,
                                                  :system_template => @system_template,
                                                  :name => "activation_key_1")
        @activation_key_1.user = mock_model(User, :username => "ak_test_user")
        @activation_key_2 = ActivationKey.create!(:environment => @environment_1, :organization => @organization, :name => "activation_key_2")
        @activation_key_1.stub(:apply_to_system,:subscribe_system)
        @activation_key_2.stub(:apply_to_system,:subscribe_system)
      end

      context "and they are correct" do

        before(:each) do
          @system = mock_model(System)
          @system.stub(:save!)
          @system.stub(:to_json).and_return("")
          System.stub(:new).and_return(@system)
          @controller.stub(:find_activation_keys).and_return([@activation_key_1,@activation_key_2])
        end

        it "uses user credentials of the user associated with the first activation key" do
          User.should_receive("current=").at_least(:once)
          User.should_receive("current=").with(@activation_key_1.user).once
          post :activate, :organization_id => @organization.cp_key, :activation_keys => "#{@activation_key_1.name},#{@activation_key_2.name}"
        end

        it "sets the environment according the activation keys" do
          @activation_key_2.should_receive(:apply_to_system)
          @activation_key_1.should_receive(:apply_to_system)
          @system.should_receive(:save!)
          post :activate, :organization_id => @organization.cp_key, :activation_keys => "#{@activation_key_1.name},#{@activation_key_2.name}"
        end

        it "should subscribe the system according to activation keys" do
          @activation_key_2.should_receive(:subscribe_system)
          @activation_key_1.should_receive(:subscribe_system)
          post :activate, :organization_id => @organization.cp_key, :activation_keys => "#{@activation_key_1.name},#{@activation_key_2.name}"
        end

      end

      context "and they are not in the system" do
        it "set the environment according the activation keys" do
          post :activate, :organization_id => @organization.cp_key, :activation_keys => "notInSystem"
          response.code.should == "404"
        end
      end
    end

  end

  describe "list systems" do
    before(:each) do
      @environment_2 = KTEnvironment.new(:name => 'test_2', :prior => @environment_1, :organization => @organization)
      @environment_2.save!

      @system_1 = System.create!(:name => 'test', :environment => @environment_1, :cp_type => 'system', :facts => facts)
      @system_2 = System.create!(:name => 'test2', :environment => @environment_2, :cp_type => 'system', :facts => facts)
    end

    let(:action) { :index }
    let(:req) { get :index, :owner => @organization.cp_key }
    let(:authorized_user) { user_with_read_permissions }
    let(:unauthorized_user) { user_without_read_permissions }
    it_should_behave_like "protected action"

    it "requires either organization_id, owner, or environment_id" do
      get :index
      response.code.should == "404"
    end

    it "should show all systems in the organization" do
      get :index, :organization_id => @organization.cp_key
      response.body.should == [@system_1, @system_2].to_json
    end

    it "should show all systems for the owner" do
      get :index, :owner => @organization.cp_key
      response.body.should == [@system_1, @system_2].to_json
    end

    it "should show only systems in the environment" do
      get :index, :environment_id => @environment_1.id
      response.body.should == [@system_1].to_json
    end

  end
  
  describe "upload package profile" do

    before(:each) do
      @sys = System.new(:name => 'test', :environment => @environment_1, :cp_type => 'system', :facts => facts, :uuid => uuid)
      System.stub!(:first).and_return(@sys)
    end

    let(:action) { :upload_package_profile }
    let(:req) { put :upload_package_profile, :id => uuid, :_json => package_profile }
    let(:authorized_user) { user_with_update_permissions }
    let(:unauthorized_user) { user_without_update_permissions }
    it_should_behave_like "protected action"

    it "successfully" do
      Pulp::Consumer.should_receive(:upload_package_profile).once.with(uuid, package_profile).and_return(true)
      put :upload_package_profile, :id => uuid, :_json => package_profile
      response.body.should == @sys.to_json
    end
  end
  
  describe "view packages in a specific system" do

    before(:each) do
      @sys = System.new(:name => 'test', :environment => @environment_1, :cp_type => 'system', :facts => facts, :uuid => uuid)
      System.stub!(:first).and_return(@sys)
    end
 
    let(:action) { :package_profile }
    let(:req) { get :package_profile, :id => uuid }
    let(:authorized_user) { user_with_read_permissions }
    let(:unauthorized_user) { user_without_read_permissions }
    it_should_behave_like "protected action"

    it "successfully" do
      @sys.should_receive(:package_profile).once.and_return(package_profile)
      get :package_profile, :id => uuid
      response.body.should == sorted.to_json
      response.should be_success
    end
  end
  
  describe "update a system" do
    before(:each) do
      @sys = System.create!(:name => 'test', :environment => @environment_1, :cp_type => 'system', :facts => facts, :uuid => uuid, :description => "fake description")
      Candlepin::Consumer.stub!(:get).and_return({:uuid => uuid})
      System.stub!(:first).and_return(@sys)
    end

    let(:action) { :update }
    let(:req) { post :update, :id => uuid, :name => "foo_name" }
    let(:authorized_user) { user_with_update_permissions }
    let(:unauthorized_user) { user_without_update_permissions }
    it_should_behave_like "protected action"
    
    it "should change the name" do
      Pulp::Consumer.should_receive(:update).once.with(@organization.cp_key, uuid, @sys.description).and_return(true)
      post :update, :id => uuid, :name => "foo_name"
      response.body.should == @sys.to_json
      response.should be_success
    end
    
    it "should change the description" do
      Pulp::Consumer.should_receive(:update).once.with(@organization.cp_key, uuid, "redkin is awesome.").and_return(true)
      post :update, :id => uuid, :description => "redkin is awesome."
      response.body.should == @sys.to_json
      response.should be_success
    end
    
    it "should change the location" do
      Pulp::Consumer.should_receive(:update).once.with(@organization.cp_key, uuid, @sys.description).and_return(true)
      post :update, :id => uuid, :location => "never-neverland"
      response.body.should == @sys.to_json
      response.should be_success
    end

    it "should update installed products" do
      @sys.facts = nil
      Candlepin::Consumer.should_receive(:update).once.with(uuid, nil, nil, installed_products).and_return(true)
      post :update, :id => uuid, :installedProducts => installed_products
      response.body.should == @sys.to_json
      response.should be_success
    end
  end

  describe "list errata" do
    before(:each) do
      @system = System.new(:name => 'test', :environment => @environment_1, :cp_type => 'system', :facts => facts, :uuid => uuid)
      System.stub!(:first).and_return(@system)
    end

    let(:action) { :errata }
    let(:req) { get :errata, :id => @system.uuid }
    let(:authorized_user) { user_with_read_permissions }
    let(:unauthorized_user) { user_without_read_permissions }
    it_should_behave_like "protected action"

    it "should find System" do
      System.should_receive(:first).once.with(hash_including(:conditions => {:uuid => @system.uuid})).and_return(@system)
      get :errata, :id => @system.uuid
    end

    it "should retrieve Consumer's errata from pulp" do
      Pulp::Consumer.should_receive(:errata).once.with(uuid).and_return([])
      get :errata, :id => @system.uuid
    end
  end

  describe "list available pools" do
    before(:each) do
      @system = System.create(:name => 'test', :environment => @environment_1, :cp_type => 'system', :facts => facts, :uuid => uuid)
      System.stub!(:first).and_return(@system)
    end

    let(:action) { :pools}
    let(:req) { get :pools, :id => @system.uuid }
    let(:authorized_user) { user_with_read_permissions }
    let(:unauthorized_user) { user_without_read_permissions }
    it_should_behave_like "protected action"

    it "should find System" do
      System.should_receive(:first).once.with(hash_including(:conditions => {:uuid => @system.uuid})).and_return(@system)
      get :pools, :id => @system.uuid
    end

    it "should retrieve avaiable pools from Candlepin" do
      #@system.should_receive(:available_pools_full).once.and_return([])
      Candlepin::Consumer.should_receive(:available_pools).once.with(uuid).and_return([])
      get :pools, :id => @system.uuid
    end
  end

end
