# frozen_string_literal: true

require 'spec_helper'

module LicenseFinder
  describe ComposerPackage do
    subject { described_class.new('a package', '1.1.1') }

    its(:package_url) { should == 'https://packagist.org/packages/a+package#1.1.1' }
  end
end
