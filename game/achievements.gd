extends RefCounted
const CATALOG=[
 {"name":"灰潮归来","power":1,"armor":0,"reward":"全队攻击 +1"},
 {"name":"逆境行者","power":0,"armor":1,"reward":"全队护甲 +1"},
 {"name":"噩梦终结","power":1,"armor":0,"reward":"全队攻击 +1"},
 {"name":"绝境传说","power":0,"armor":1,"reward":"全队护甲 +1"}]

static func valid(value) -> bool:
 if not value is Array:return false
 var seen=[]
 for rank in value:
  if not (rank is int or rank is float):return false
  if not is_finite(float(rank)) or float(rank)!=floor(float(rank)) or rank<0 or rank>=CATALOG.size() or rank in seen:return false
  seen.append(rank)
 return true

static func load_profile(path: String) -> Array:
 if not FileAccess.file_exists(path):return []
 var parsed=JSON.new()
 if parsed.parse(FileAccess.get_file_as_string(path))!=OK:return []
 return parsed.data if valid(parsed.data) else []

static func save_profile(path: String,ranks: Array) -> bool:
 var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify(ranks));file.flush()
 var error=file.get_error();file.close()
 if error!=OK:return false
 return DirAccess.rename_absolute(path+".tmp",path)==OK

static func bonus(ranks: Array) -> Dictionary:
 var result={"power":0,"armor":0}
 for rank in ranks:
  result.power+=CATALOG[int(rank)].power
  result.armor+=CATALOG[int(rank)].armor
 return result
