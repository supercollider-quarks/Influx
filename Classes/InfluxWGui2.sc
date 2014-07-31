InfluxWGui2 : JITGui {

	accepts { |obj| ^obj.isNil or: { obj.isKindOf(Influx) } }

}