#!/usr/bin/env ruby
# expand_boot.rb: resize boot partition on r5s Android/Android TV images from 40MB to 100MB
# Usage: replace original mtd to the generated mtd string in parameter.txt (eflasher)
mtd = '0x00002000@0x00002000(security),0x00002000@0x00004000(uboot),0x00002000@0x00006000(trust),0x00002000@0x00008000(misc),0x00002000@0x0000a000(dtbo),0x00002000@0x0000c000(vbmeta),0x00014000@0x0000e000(boot),0x00036000@0x00022000(recovery),0x000ba000@0x00058000(backup),0x00040000@0x00112000(cache),0x00008000@0x00152000(metadata),0x00002000@0x0015a000(baseparameter),0x00500000@0x0015c000(super),-@0x0065c000(userdata:grow)'

partinfo = mtd.split(',').to_h do |part|
  size, offset, name = part.scan(/^([\-a-z\d]+?)@(0x[a-z\d]+)\((.+)\)$/).flatten
  next [ name, {size: size, offset: offset} ]
end

origsize = partinfo['boot'][:size].to_i(16)
newsize  = 100 * 1024 * 2 # 100MB

partinfo['boot'][:size] = format('0x%08x', newsize)

%w[recovery backup cache metadata baseparameter super userdata:grow].each do |partition|
  partinfo[partition][:offset] = format('0x%08x', partinfo[partition][:offset].to_i(16) + (newsize - origsize))
end

newmtd = partinfo.map do |partname, meta|
  "#{meta[:size]}@#{meta[:offset]}(#{partname})"
end.join(',')

puts <<~EOT
Original: #{mtd}
New:      #{newmtd}
EOT
