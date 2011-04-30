# using CPAN as backend

require 'nokogiri'
require 'net/http'
require 'shellwords'

repository.do {
  def each_package
    cpan

    `#{%|perl -MCPAN -e 'print join("\\n", map {$_->{ID}."-".$_->{RO}->{CPAN_|+
      %|VERSION}} CPAN::Shell->expand("Module", "/./"))'|}`.each_line{|line|
      line.strip!
      next unless line.match(/^((?:\w+::)*\w+)-(.+)$/)

      name, version = line.split(?-, 2)

      yield Package.new(
        tags:     ['perl', 'cpan'],
        name:     name,
        version:  version.gsub('undef', ?0)
      )
    }
  end

  def each_dependency(package)
    self.get_deps(package.name).each {|name|
      yield Package.new(
        tags:     ['perl', 'cpan'],
        name:     name,
        version:  nil
      )
    }
  end

  def install(package)
    cpan('-i', package.name)
    Packo.contents(`cpan_files #{Shellwords.escape(package.name)}`.lines)
  end

  def uninstall(package)
  end

protected
  def perl_version
    @@perl_version ||= `perl -MConfig -e 'print $Config{version};'`
  end

  def get_deps(pkg)
    Nokogiri::XML(
      Net::HTTP.get(
        URI.parse("http://deps.cpantesters.org/?xml=1;module=%s;perl=%s;os=any%%20OS;pureperl=0" %
                  [pkg, perl_version].map {|s| URI.encode(s) }))).xpath('//cpandeps/dependency').select {|node|
      node.xpath(node.path + '/depth').text == ?1
    }.map {|node|
      node.xpath(node.path + '/module').text
    }
  end

  def cpan(*args)
    if Process.uid != 0
      root = File.join(ENV['HOME'], '.cpan')
      lock = File.join(root, '.lock')

      File.unlink(lock) if File.file?(lock)
      `echo -e "yes\nyes" | cpan` if !File.file?(File.join(root, 'CPAN', 'MyConfig.pm'))
    end

    Packo.sh('cpan', *args) if args > 0
  end
}

__END__
---

--- bin/cpan_files ---

#!/usr/bin/env perl

use strict;
use ExtUtils::Installed;
use List::Util qw(first);

$\ = "\n";

$ARGV[0] or die "Usage: $0 Module::Name";

my $mod = $ARGV[0];

die "Does not looks like a module name"
  unless $mod =~ m{^\w+(::\w+)*$};

my $inst = ExtUtils::Installed->new();

die "Can't find module $mod using .packlist files"
  unless first { $_ eq $mod } ( $inst->modules );

foreach my $item ( sort( $inst->files($mod) ) ) {
  print $item
}

print $inst->packlist($mod)->packlist_file();
