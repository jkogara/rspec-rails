require "spec_helper"

class ::ApplicationController
  def self.abstract?; false; end
end

module RSpec::Rails
  describe ControllerExampleGroup do
    it_behaves_like "an rspec-rails example group mixin", :controller,
      './spec/controllers/', '.\\spec\\controllers\\'

    def group_for(klass)
      RSpec::Core::ExampleGroup.describe klass do
        include ControllerExampleGroup
      end
    end

    let(:group) { group_for ApplicationController }

    it "includes routing matchers" do
      expect(group.included_modules).to include(RSpec::Rails::Matchers::RoutingMatchers)
    end

    context "with implicit subject" do
      it "uses the controller as the subject" do
        controller = double('controller')
        example = group.new
        allow(example).to receive_messages(:controller => controller)
        expect(example.subject).to eq(controller)
      end
    end

    context "with explicit subject" do
      it "uses the specified subject instead of the controller" do
        sub_group = group.describe do
          subject { 'explicit' }
        end
        example = sub_group.new
        expect(example.subject).to eq('explicit')
      end
    end

    describe "#controller" do
      before do
        group.class_eval do
          controller(Class.new) { }
        end
      end

      it "delegates named route helpers to the underlying controller" do
        controller = double('controller')
        allow(controller).to receive(:foos_url).and_return('http://test.host/foos')

        example = group.new
        allow(example).to receive_messages(:controller => controller)

        # As in the routing example spec, this is pretty invasive, but not sure
        # how to do it any other way as the correct operation relies on before
        # hooks
        routes = nil
        with_isolated_stderr do
          routes = ActionDispatch::Routing::RouteSet.new
          routes.draw { resources :foos }
        end
        example.instance_variable_set(:@orig_routes, routes)

        expect(example.foos_url).to eq('http://test.host/foos')
      end
    end

    describe "#bypass_rescue" do
      it "overrides the rescue_with_handler method on the controller to raise submitted error" do
        example = group.new
        example.instance_variable_set("@controller", Class.new { def rescue_with_handler(e); end }.new)
        example.bypass_rescue
        expect do
          example.controller.rescue_with_handler(RuntimeError.new("foo"))
        end.to raise_error("foo")
      end
    end

    describe "with inferred anonymous controller" do
      let(:anonymous_klass) { Class.new }
      let(:group) { group_for(anonymous_klass) }

      it "defaults to inferring anonymous controller class" do
        expect(RSpec.configuration.infer_base_class_for_anonymous_controllers).to be_truthy
      end

      context "when infer_base_class_for_anonymous_controllers is true" do
        around(:example) do |ex|
          with_isolated_config do |config|
            config.infer_base_class_for_anonymous_controllers = true
            ex.run
          end
        end

        it "infers the anonymous controller class" do
          group.controller { }
          expect(group.controller_class.superclass).to eq(anonymous_klass)
        end

        it "infers the anonymous controller class when no ApplicationController is present" do
          hide_const '::ApplicationController'
          group.controller { }
          expect(group.controller_class.superclass).to eq(anonymous_klass)
        end
      end

      context "when infer_base_class_for_anonymous_controllers is false" do
        around(:example) do |ex|
          with_isolated_config do |config|
            config.infer_base_class_for_anonymous_controllers = false
            ex.run
          end
        end

        it "sets the anonymous controller class to ApplicationController" do
          group.controller { }
          expect(group.controller_class.superclass).to eq(ApplicationController)
        end

        it "sets the anonymous controller class to ActiveController::Base when no ApplicationController is present" do
          hide_const '::ApplicationController'
          group.controller { }
          expect(group.controller_class.superclass).to eq(ActionController::Base)
        end
      end
    end

    describe "controller name" do
      let(:controller_class) { group.controller_class }

      it "sets the name as AnonymousController if it's anonymous" do
        group.controller { }
        expect(controller_class.name).to eq "AnonymousController"
      end

      it "sets the name according to defined controller if it is not anonymous" do
        stub_const "FoosController", Class.new(::ApplicationController)
        group.controller(FoosController) { }
        expect(controller_class.name).to eq "FoosController"
      end

      it "sets name as AnonymousController if defined as ApplicationController" do
        group.controller(ApplicationController) { }
        expect(controller_class.name).to eq "AnonymousController"
      end

      it "sets name as AnonymousController if the controller is abstract" do
        abstract_controller = Class.new(::ApplicationController)
        def abstract_controller.abstract?; true; end

        group.controller(abstract_controller) { }
        expect(controller_class.name).to eq "AnonymousController"
      end
    end

    context "in a namespace" do
      describe "controller name" do
        let(:controller_class) { group.controller_class }

        it "sets the name according to the defined controller namespace if it is not anonymous" do
          stub_const "A::B::FoosController", Class.new(::ApplicationController)
          group.controller(A::B::FoosController) { }
          expect(controller_class.name).to eq "A::B::FoosController"
        end

        it "sets the name as 'AnonymousController' if the controller is abstract" do
          abstract_controller = Class.new(::ApplicationController)
          def abstract_controller.abstract?; true; end
          stub_const "A::B::FoosController", abstract_controller

          group.controller(A::B::FoosController) { }
          expect(controller_class.name).to eq "AnonymousController"
        end
      end

      pending "sets up resourceful routes on the example"
    end
  end
end
