package autoincr

type AutoIncrementTracker interface {
	GetAutoIncrementValueForTable(dbname, tableName string) (uint64, bool)
	SetAutoIncrementValueForTable(dbname, tableName string, val uint64) bool
}

func NewAutoIncrementTracker() AutoIncrementTracker {
	return &autoIncrementTracker{
		tables: make(map[string]map[string]uint64),
	}
}

type autoIncrementTracker struct {
	tables map[string]map[string]uint64
}

var _ AutoIncrementTracker = (*autoIncrementTracker)(nil)

func (a *autoIncrementTracker) GetAutoIncrementValueForTable(dbname, tableName string) (uint64, bool) {
	return a.tables[dbname][tableName], true
}

func (a *autoIncrementTracker) SetAutoIncrementValueForTable(dbname, tableName string, val uint64) bool {
	dbTable := a.tables[dbname]
	if dbTable == nil {
		a.tables[dbname] = make(map[string]uint64)
		dbTable = a.tables[dbname]
	}

	dbTable[tableName] = val

	return true
}
