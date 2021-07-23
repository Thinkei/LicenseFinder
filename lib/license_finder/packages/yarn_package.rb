# frozen_string_literal: true

module LicenseFinder
  class YarnPackage < Package
    attr_writer :children

    def package_manager
      'Yarn'
    end

    def package_url
      "https://yarn.pm/#{CGI.escape(name)}"
    end
  end
end
