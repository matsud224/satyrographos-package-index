require 'erb'

package_name = 'class-yabaitech'
latest_version = '1.2.3'

erb = ERB.new(ARGF.read).run(binding)
