///|
pub(all) struct ZipEntry {
  name : String
  content : Bytes
}

///|
fn zip_crc32(bytes : Bytes) -> UInt {
  let table : Array[UInt] = []
  for i = 0; i < 256; i = i + 1 {
    let mut n = i.reinterpret_as_uint()
    for bit = 0; bit < 8; bit = bit + 1 {
      n = (n >> 1) ^ (if (n & 1U) != 0U { 0xEDB88320U } else { 0U })
    }
    table.push(n)
  }
  let mut crc = 0xFFFFFFFFU
  for i = 0; i < bytes.length(); i = i + 1 {
    crc = (crc >> 8) ^
      table[((crc ^ bytes[i].to_int().reinterpret_as_uint()) & 255U).reinterpret_as_int()]
  }
  crc ^ 0xFFFFFFFFU
}

///|
fn zip_u16(buffer : @buffer.Buffer, value : Int) -> Unit {
  buffer.write_byte((value & 255).to_byte())
  buffer.write_byte(((value >> 8) & 255).to_byte())
}

///|
fn zip_entry_budget(
  current : Int,
  name_bytes : Int,
  content_bytes : Int,
) -> Int raise {
  let overhead = 76 + 2 * name_bytes
  if current < 22 ||
    name_bytes < 1 ||
    name_bytes > 255 ||
    content_bytes < 0 ||
    current > 67108864 - overhead ||
    content_bytes > 67108864 - overhead - current {
    raise InvalidInput("ZIP exceeds the 64 MiB archive limit")
  }
  current + overhead + content_bytes
}

///|
pub fn encode_site_zip(entries : Array[ZipEntry]) -> Bytes raise {
  if entries.length() > 10000 {
    raise InvalidInput("ZIP exceeds 10000 files")
  }
  let sorted = entries.copy()
  sorted.sort_by((a, b) => a.name.compare(b.name))
  let seen : Map[String, Bool] = Map([])
  let mut size = 22
  for entry in sorted {
    if !safe_output_name(entry.name) ||
      (entry.name.has_prefix(".") && entry.name != ".nojekyll") ||
      seen.contains(entry.name) {
      raise InvalidInput(
        "Unsafe, internal or duplicate ZIP filename: " + entry.name,
      )
    }
    seen[entry.name] = true
    size = zip_entry_budget(
      size,
      @utf8.encode(entry.name).length(),
      entry.content.length(),
    )
  }
  let buffer = @buffer.Buffer(size_hint=size)
  let offsets : Array[Int] = []
  let checksums : Array[UInt] = []
  for entry in sorted {
    let name = @utf8.encode(entry.name)
    let crc = zip_crc32(entry.content)
    offsets.push(buffer.length())
    checksums.push(crc)
    buffer.write_int_le(0x04034b50)
    for value in [20, 0x0800, 0, 0, 33] {
      zip_u16(buffer, value)
    }
    buffer.write_uint_le(crc)
    buffer.write_int_le(entry.content.length())
    buffer.write_int_le(entry.content.length())
    zip_u16(buffer, name.length())
    zip_u16(buffer, 0)
    buffer.write_bytes(name)
    buffer.write_bytes(entry.content)
  }
  let central_offset = buffer.length()
  for i = 0; i < sorted.length(); i = i + 1 {
    let entry = sorted[i]
    let name = @utf8.encode(entry.name)
    buffer.write_int_le(0x02014b50)
    for value in [0x0314, 20, 0x0800, 0, 0, 33] {
      zip_u16(buffer, value)
    }
    buffer.write_uint_le(checksums[i])
    buffer.write_int_le(entry.content.length())
    buffer.write_int_le(entry.content.length())
    for value in [name.length(), 0, 0, 0, 0] {
      zip_u16(buffer, value)
    }
    buffer.write_int_le(0x81A40000)
    buffer.write_int_le(offsets[i])
    buffer.write_bytes(name)
  }
  let central_size = buffer.length() - central_offset
  buffer.write_int_le(0x06054b50)
  for value in [0, 0, sorted.length(), sorted.length()] {
    zip_u16(buffer, value)
  }
  buffer.write_int_le(central_size)
  buffer.write_int_le(central_offset)
  zip_u16(buffer, 0)
  buffer.to_bytes()
}
