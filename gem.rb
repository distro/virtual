# using gem as backend

require 'rubygems/dependency_installer'

repository.do {
  def versionify (version)
    Versionub.parse(version)
  rescue Exception => e
    '0'
  end

  def each_package (&block)
    @data ||= YAML.parse(filesystem.data.to_s).transform

    `gem list --remote`.lines.each {|line|
      CLI.info "Parsing `#{line.chomp}`" if System.env[:VERBOSE]

      whole, name, version = line.match(/^(.+?) \((.+?)\)$/).to_a

      unless name && version
        CLI.warn "`#{line.chomp}` was not parsed succesfully" if System.env[:VERBOSE]
        next
      end

      block.call Package.new(
        tags:    ['ruby', 'gem'] + ((data[name]['tags'] rescue nil) || []),
        name:    name,
        version: versionify(version)
      )
    }
  end

  def each_dependency (package, &block)
    @data ||= YAML.parse(filesystem.data.to_s).transform

    package.envify!

    deptypes = [:runtime]
    deptypes << :development if package.flavor.development?

    if !package.version
      package.version = gem_version(package.name)
    elsif package.version == '9999'
      package.version = [gem_version(package.name), gem_version(package.name, nil, true)].compact.max
    end

    YAML.load(Packo.sh('gem', 'specification', '-r', package.name, '--version', package.version, catch: true)).dependencies.each {|dep|
      next if !deptypes.include?(dep.type)

      block.call Package.new(
        tags:     ['ruby', 'gem'] + ((data[dep.name]['tags'] rescue nil) || []),
        name:     dep.name,
        version:  gem_version(dep.name, dep.requirement.to_s, package.version == '9999')
      )
    }

    ((data[dep.name]['dependencies'] rescue nil) || []).each {|dep|
      block.call Package.new(
        name:     dep,
        version:  nil
      )
    }
  end

  def has? (package)
    version = package.version ? "= #{package.version}" : Gem::Requirement.default

    !!(gem_version(package.name, version) or gem_version(package.name, version, true))
  end

  def install (package)
    package.envify!

    args = []

    if package.flavor.vanilla? || package.flavor.documentation?
      args += ['--rdoc', '--ri']
    else
      args += ['--no-rdoc', '--no-ri']
    end

    if package.flavor.development?
      args << '--development'
    end

    if !package.version
      package.version = gem_version(package.name)
    elsif package.version == '9999'
      package.version = [gem_version(package.name), gem_version(package.name, nil, true)].compact.max
    end

    gem_install(*args, package.name, '--version', package.version.to_s)

    files = Packo.sh('gem', 'contents', package.name, '--version', package.version, catch: true).lines.to_a

    if $? != 0
      raise RuntimeError.new 'Gem failed'
    end

    package = package.clone
    package.contents = Packo.contents(files)
    package.dependencies = Package::Dependencies.new(package)

    self.dependencies(package).each {|dep|
      package.dependencies << Package::Dependency.new(dep.to_hash)
    }

    package
  end

  def gem_install (*args)
    if Packo.user?
      args.unshift '--user-install'
    end

    args.unshift '-E'

    Packo.sh('gem', 'install', *args)

    if $? != 0
      raise RuntimeError.new 'Gem failed'
    end
  end

  def gem_version (gem_name, gem_version=nil, pre=false)
    gem_version ||= Gem::Requirement.default

    version = Gem::DependencyInstaller.new.find_spec_by_name_and_version(gem_name, gem_version, pre).sort_by {|x|
      Versionub.parse(x.first.version.to_s)
    }.last.first.version.to_s

    versionify(version) if version
  rescue
    nil
  end
}

__END__
$$$

$$$ data $$$

---
dm-sqlite-adapter:
  tags:
    - datamapper
    - database

  dependencies:
    - database/sqlite

