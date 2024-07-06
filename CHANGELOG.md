# v2.0.0 -- 05 Jul 2024

This is a major rewrite of [xmlToTable](https://github.com/rabbitboots/xml_to_table). Unfortunately, there are so many changes that it's not possible to write a straightforward upgrade guide. The main improvements are:

* UTF-16 support (internal conversion to UTF-8)
* Parsing of DOCTYPE tags and the DTD internal subset (in a non-validating manner)
* More conformant handling of whitespace
* Serialization has been promoted from "for debugging purposes" to an official feature
* Attribute order is discarded; duplicate attributes are not allowed at all. It was a mistake to order attributes in the first place.
* XML Declarations are now handled
* Support for `xml:space="preserve"` when pruning whitespace
* Some support for XML Namespaces 1.0 and 1.1
