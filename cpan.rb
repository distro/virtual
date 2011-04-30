# using CPAN as backend

require 'nokogiri'
require 'net/http'

repository.do {
  if Packo.protected?
    CLI.warn 'Run packo repository in unprotected mode (packo-repository) or CPAN may not work'
  end

  def each_package (&block)
    cpan

    `perl -MCPAN -e 'print join("\\n", map {$_->{ID}."-".$_->{RO}->{CPAN_VERSION}} CPAN::Shell->expand("Module", "/./"))'`.each_line {|line|
      CLI.info "Parsing `#{line.chomp}`" if System.env[:VERBOSE]

      whole, name, version = line.strip.match(/^((?:\w+::)*\w+)-([^\-]+)$/).to_a

      next unless whole

      block.call Package.new(
        tags:     ['perl', 'cpan'],
        name:     name,
        version:  version.gsub('undef', '0')
      )
    }

    if $? != 0
      raise RuntimeError.new 'CPAN failed'
    end
  end

  def each_dependency (package, &block)
    self.get_deps(package.name).each {|name|
      block.call Package.new(
        tags:    ['perl', 'cpan'],
        name:    name,
        version: nil
      )
    }
  end

  def install (package)
    cpan('-i', package.name)

    Packo.contents(filesystem.bin.cpan_files.execute(package.name).lines)
  end

  def uninstall (package)
  end

  memoize
  def perl_version
    `perl -MConfig -e 'print $Config{version};'`
  end

  def get_deps (package)
    Nokogiri::XML(Net::HTTP.get(URI.parse("http://deps.cpantesters.org/?xml=1;module=%s;perl=%s;os=any%%20OS;pureperl=0" %
      [package, perl_version].map {|s| URI.encode(s) }))).xpath('//cpandeps/dependency').select {|node|
        node.xpath(node.path + '/depth').text == '1'
      }.map {|node|
        node.xpath(node.path + '/module').text
      }
  end

  def cpan (*args)
    if Process.uid != 0
      root = File.join(ENV['HOME'], '.cpan')
      lock = File.join(root, '.lock')

      File.unlink(lock) if File.file?(lock)

      if !File.file?(File.join(root, 'CPAN', 'MyConfig.pm'))
        `echo -e "yes\nyes" | cpan`
      end
    end

    Packo.sh('cpan', *args) if args.length > 0
  end
}

__END__
---

--- bin/cpan_files ---

#! /usr/bin/env perl

use strict;
use warnings;
use ExtUtils::Installed;
use List::Util qw(first);

$\ = "\n";

$ARGV[0] or die "Usage: $0 Module::Name";

my $mod = $ARGV[0];

die "Does not look like a module name"
  unless $mod =~ m{^\w+(::\w+)*$};

my $inst = ExtUtils::Installed->new();

die "Can't find module $mod using .packlist files"
  unless first { $_ eq $mod } ( $inst->modules );

foreach my $item ( sort( $inst->files($mod) ) ) {
  print $item
}

print $inst->packlist($mod)->packlist_file();
