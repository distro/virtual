# using gem as backend

require 'nokogiri'

repository.do {
  def each_package (&block)
    dom = Nokogiri::XML.parse(filesystem.data.to_s)

    `gem list --remote`.lines.each {|line|
      CLI.info "Parsing `#{line.chomp}`" if System.env[:VERBOSE]

      t, name, version = line.match(/^(.+?) \((.+?)\)$/).to_a

      unless name && version
        CLI.warn "`#{line.chomp}` was not parsed succesfully" if System.env[:VERBOSE]
        next
      end

      begin
        Versionomy.parse(version)
      rescue Versionomy::Errors::ParseError => e
        version.sub!(e.message.match(/Extra characters: "(.*?)"/).to_a.last, '')
      end

      block.call(Package.new(
        :tags    => ['ruby', 'gem'] + ((dom.xpath(%{//gem[name = "#{name}"]/tags}).first.text.split(/\s+/) rescue nil) || []),
        :name    => name,
        :version => version
      ))
    }
  end

  def install (name)

  end

  def uninstall (name)

  end
}

__END__
$$$

$$$ data $$$

<data>
  <gem name="dm-sqlite-adapter">
    <tags>datamapper database</tags>

    <dependency>database/sqlite</dependency>
  </gem>
</data>
