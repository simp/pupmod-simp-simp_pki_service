# Structure of the 'config_hash' for 'config_item' calls
type Simp_pki_service::Ca::ConfigItemHash = Hash[
  String[1],
  Variant[
    String[1],
    Boolean,
    Numeric,
    Array[String[1]
    ]
  ]
]
