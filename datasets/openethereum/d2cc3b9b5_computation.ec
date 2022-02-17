commit d2cc3b9b5ba7b5af683fbffe2ca981ab9c7d1088
Author: Gav Wood <gav@ethcore.io>
Date:   Thu Jan 14 22:16:41 2016 +0100

    Remove unnecessary unwraps in json_aid.

diff --git a/src/json_aid.rs b/src/json_aid.rs
index 6c9925ffc..e25e9406d 100644
--- a/src/json_aid.rs
+++ b/src/json_aid.rs
@@ -18,27 +18,31 @@ fn u256_from_str(s: &str) -> U256 {
 
 impl FromJson for Bytes {
 	fn from_json(json: &Json) -> Self {
-		let s = json.as_string().unwrap_or("");
-		if s.len() % 2 == 1 {
-			FromHex::from_hex(&("0".to_string() + &(clean(s).to_string()))[..]).unwrap_or(vec![])
-		} else {
-			FromHex::from_hex(clean(s)).unwrap_or(vec![])
+		match json {
+			&Json::String(ref s) => match s.len() % 2 {
+				0 => FromHex::from_hex(clean(s)).unwrap_or(vec![]),
+				_ => FromHex::from_hex(&("0".to_string() + &(clean(s).to_string()))[..]).unwrap_or(vec![]),
+			},
+			_ => vec![],
 		}
 	}
 }
 
 impl FromJson for BTreeMap<H256, H256> {
 	fn from_json(json: &Json) -> Self {
-		json.as_object().unwrap().iter().fold(BTreeMap::new(), |mut m, (key, value)| {
-			m.insert(x!(&u256_from_str(key)), x!(&U256::from_json(value)));
-			m
-		})
+		match json {
+			&Json::Object(ref o) => o.iter().map(|(key, value)| (x!(&u256_from_str(key)), x!(&U256::from_json(value)))).collect(),
+			_ => BTreeMap::new(),
+		}
 	}
 }
 
 impl<T> FromJson for Vec<T> where T: FromJson {
 	fn from_json(json: &Json) -> Self {
-		json.as_array().unwrap().iter().map(|x|T::from_json(x)).collect()
+		match json {
+			&Json::Array(ref o) => o.iter().map(|x|T::from_json(x)).collect(),
+			_ => Vec::new(),
+		}
 	}
 }
 
