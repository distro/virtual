# using CPAN as backend
#
# http://www.perl.com/CPAN/modules/02packages.details.txt

require 'uri'
require 'net/http'

repository.do {
  def each_package (&block)
    eval(Net::HTTP.get(URI.parse('http://www.cpan.org/modules/03modlist.data')) \
      .sub(/\A.*?data = \[\s*$/m, '[') \
      .gsub(/\\x\{(.*?)\}/, '')
    ).each {|(name, *stats, description, user, chapter)|
      
    }
  end
}
