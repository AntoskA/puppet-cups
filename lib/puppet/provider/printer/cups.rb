# TODO: Consider enable/disable, accept/reject and options as property methods.
# TODO: Consider parsing lpstat -l -p for more detail on prefetch
# TODO: lpstat -v for device-uris in prefetch
# TODO: change of device uri should imply destroy+create

Puppet::Type.type(:printer).provide :cups, :parent => Puppet::Provider do
  desc "This provider manages installed printers using CUPS command line tools"

  commands :lpadmin => "/usr/sbin/lpadmin"
  commands :lpoptions => "/usr/bin/lpoptions"
  commands :lpinfo => "/usr/sbin/lpinfo"
  commands :lpstat => "/usr/bin/lpstat"

  commands :cupsenable => "/usr/sbin/cupsenable"
  commands :cupsdisable => "/usr/sbin/cupsdisable"

  commands :cupsaccept => "/usr/sbin/cupsaccept"
  commands :cupsreject => "/usr/sbin/cupsreject"

  # A hash of possible parameters to their command-line equivalents.
  Cups_Options = {
      :uri => '-v "%s"',
      :description => '-D "%s"',
      :location => '-L "%s"',
      :ppd => '-P "%s"'
  }

  class << self

    def printers
      lpstat('-p').split("\n").map { |line|
        line.match(/printer (.*) is/).captures[0]
      }
    end

    # Retrieve options
    def printer_options(destination)
      options = {}

      lpoptions('-d', destination).split(' ').each do |pair|
        kv = pair.split('=')
        options[kv[0]] = kv[1]
      end

      options
    end

    # Retrieve Device-uri's
    def printer_uris
      uris = {}

      lpstat('-v').split("\n").each { |line|
        caps = line.match(/device for ([^:]*) (.*)/).captures
        uris[caps[0]] = caps[1]
      }

      uris
    end

    def prefetch(resources)
      printers.collect { |p|
        new({ :name => p, :provider => :cups })
      }
    end
  end

  def create
    options = Array.new

    # Handle most parameters via string substitution
    Cups_Options.keys.each do |k|
      options.unshift Cups_Options[k] % @resource[k] if @resource.parameters.key?(k)
    end

    options.push '-o printer-is-shared=true' if @resource[:shared]
    options.push '-E' if @resource[:enabled]

    lpadmin "-p", @resource[:name], options
  end

  def destroy
    lpadmin "-x", @resource[:name]
  end

  def exists?
    #TODO: lpadmin considers printer names case-insensitive, use case-insensitive match
    self.class.printers.include? @resource[:name]
  end
end