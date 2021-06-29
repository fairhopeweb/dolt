// Copyright 2021 Dolthub, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package merge

import (
	"context"
	"fmt"
	"io"
	"time"

	"github.com/dolthub/dolt/go/libraries/doltcore/diff"
	"github.com/dolthub/dolt/go/libraries/doltcore/doltdb"
	"github.com/dolthub/dolt/go/libraries/doltcore/row"
	"github.com/dolthub/dolt/go/libraries/doltcore/schema"
	"github.com/dolthub/dolt/go/libraries/doltcore/table"
	"github.com/dolthub/dolt/go/libraries/doltcore/table/editor"
	"github.com/dolthub/dolt/go/libraries/doltcore/table/typed/noms"
	diff2 "github.com/dolthub/dolt/go/store/diff"
	"github.com/dolthub/dolt/go/store/types"
)

// constraintViolationsLoadedTable is a collection of items needed to process constraint violations for a single table.
type constraintViolationsLoadedTable struct {
	TableName   string
	Table       *doltdb.Table
	Schema      schema.Schema
	RowData     types.Map
	Index       schema.Index
	IndexSchema schema.Schema
	IndexData   types.Map
}

// AddConstraintViolations adds all constraint violations to each table.
func AddConstraintViolations(ctx context.Context, newRoot, ourRoot, baseRoot *doltdb.RootValue) (*doltdb.RootValue, error) {
	fkColl, err := newRoot.GetForeignKeyCollection(ctx)
	if err != nil {
		return nil, err
	}
	for _, foreignKey := range fkColl.AllKeys() {
		postParent, ok, err := newConstraintViolationsLoadedTable(ctx, foreignKey.ReferencedTableName, foreignKey.ReferencedTableIndex, newRoot)
		if err != nil {
			return nil, err
		}
		if !ok {
			return nil, fmt.Errorf("foreign key %s should have index %s on table %s but it cannot be found",
				foreignKey.Name, foreignKey.ReferencedTableIndex, foreignKey.ReferencedTableName)
		}

		postChild, ok, err := newConstraintViolationsLoadedTable(ctx, foreignKey.TableName, foreignKey.TableIndex, newRoot)
		if err != nil {
			return nil, err
		}
		if !ok {
			return nil, fmt.Errorf("foreign key %s should have index %s on table %s but it cannot be found",
				foreignKey.Name, foreignKey.TableIndex, foreignKey.TableName)
		}

		preParentExists := false
		preParent, _, err := newConstraintViolationsLoadedTable(ctx, foreignKey.ReferencedTableName, "", ourRoot)
		if err != nil {
			if err != doltdb.ErrTableNotFound {
				return nil, err
			}
		} else {
			preParentExists = true
		}

		preChildExists := false
		preChild, _, err := newConstraintViolationsLoadedTable(ctx, foreignKey.TableName, "", ourRoot)
		if err != nil {
			if err != doltdb.ErrTableNotFound {
				return nil, err
			}
		} else {
			preChildExists = true
		}

		switch {
		case preParentExists && preChildExists:
			postChild.Table, err = parentFkConstraintViolations(ctx, foreignKey, preParent, postParent, postChild)
			if err != nil {
				return nil, err
			}
			postChild.RowData, err = postChild.Table.GetRowData(ctx)
			if err != nil {
				return nil, err
			}
			postChild.Table, err = childFkConstraintViolations(ctx, foreignKey, postParent, preChild, postChild)
			if err != nil {
				return nil, err
			}
		case preParentExists && !preChildExists:
			// We remove CASCADE and SET NULL when adding the child table (they're not used when the parent is added)
			foreignKey.OnDelete = doltdb.ForeignKeyReferenceOption_Restrict
			baseParent, _, err := newConstraintViolationsLoadedTable(ctx, foreignKey.ReferencedTableName, "", baseRoot)
			if err != nil {
				return nil, err
			}
			postChild.Table, err = parentFkConstraintViolations(ctx, foreignKey, baseParent, postParent, postChild)
			if err != nil {
				return nil, err
			}
		case !preParentExists && preChildExists:
			baseChild, _, err := newConstraintViolationsLoadedTable(ctx, foreignKey.TableName, "", baseRoot)
			if err != nil {
				return nil, err
			}
			postChild.Table, err = childFkConstraintViolations(ctx, foreignKey, postParent, baseChild, postChild)
			if err != nil {
				return nil, err
			}
		case !preParentExists && !preChildExists:
			// Both tables added by merge so no checks are done
		}

		newRoot, err = newRoot.PutTable(ctx, postChild.TableName, postChild.Table)
		if err != nil {
			return nil, err
		}
	}
	return newRoot, nil
}

// parentFkConstraintViolations processes foreign key constraint violations for the parent in a foreign key.
func parentFkConstraintViolations(
	ctx context.Context,
	foreignKey doltdb.ForeignKey,
	preParent, postParent, postChild *constraintViolationsLoadedTable,
) (*doltdb.Table, error) {
	postParentIndexTags := postParent.Index.IndexedColumnTags()
	postChildIndexTags := postChild.Index.IndexedColumnTags()
	postChildCVMap, err := postChild.Table.GetConstraintViolations(ctx)
	if err != nil {
		return nil, err
	}
	postChildCVMapEditor := postChildCVMap.Edit()
	postChildTableEditor, err := editor.NewTableEditor(ctx, postChild.Table, postChild.Schema, foreignKey.TableName)
	if err != nil {
		return nil, err
	}

	differ := diff.NewRowDiffer(ctx, preParent.Schema, postParent.Schema, 1024)
	defer differ.Close()
	differ.Start(ctx, preParent.RowData, postParent.RowData)
	for {
		diffSlice, hasMore, err := differ.GetDiffs(1, 10*time.Second)
		if err != nil {
			return nil, err
		}
		if len(diffSlice) != 1 {
			if hasMore {
				return nil, fmt.Errorf("no diff returned but should have errored earlier")
			}
			break
		}
		rowDiff := diffSlice[0]
		switch rowDiff.ChangeType {
		case types.DiffChangeRemoved, types.DiffChangeModified:
			postParentRow, err := row.FromNoms(postParent.Schema, rowDiff.KeyValue.(types.Tuple), rowDiff.OldValue.(types.Tuple))
			if err != nil {
				return nil, err
			}
			hasNulls := false
			for _, tag := range postParentIndexTags {
				if postParentRowEntry, ok := postParentRow.GetColVal(tag); !ok || types.IsNull(postParentRowEntry) {
					hasNulls = true
					break
				}
			}
			if hasNulls {
				continue
			}

			postParentIndexPartialKey, err := row.ReduceToIndexPartialKey(postParent.Index, postParentRow)
			if err != nil {
				return nil, err
			}

			shouldContinue, err := func() (bool, error) {
				var mapIter table.TableReadCloser = noms.NewNomsRangeReader(postParent.IndexSchema, postParent.IndexData,
					[]*noms.ReadRange{{Start: postParentIndexPartialKey, Inclusive: true, Reverse: false, Check: func(tuple types.Tuple) (bool, error) {
						return tuple.StartsWith(postParentIndexPartialKey), nil
					}}})
				defer mapIter.Close(ctx)
				if _, err := mapIter.ReadRow(ctx); err == nil {
					// If the parent has more rows that satisfy the partial key then we choose to do nothing
					return true, nil
				} else if err != io.EOF {
					return false, err
				}
				return false, nil
			}()
			if shouldContinue {
				continue
			}

			postParentIndexPartialKeySlice, err := postParentIndexPartialKey.AsSlice()
			if err != nil {
				return nil, err
			}
			for i := 0; i < len(postChildIndexTags); i++ {
				postParentIndexPartialKeySlice[2*i] = types.Uint(postChildIndexTags[i])
			}
			postChildIndexPartialKey, err := types.NewTuple(postChild.Table.Format(), postParentIndexPartialKeySlice...)
			if err != nil {
				return nil, err
			}
			err = parentFkConstraintViolationsProcess(ctx, foreignKey, postChild, postChildIndexPartialKey, postChildCVMapEditor, postChildTableEditor)
		case types.DiffChangeAdded:
			// We don't do anything if a parent row was added
		default:
			return nil, fmt.Errorf("unknown diff change type")
		}
		if !hasMore {
			break
		}
	}

	postChildCVMap, err = postChildCVMapEditor.Map(ctx)
	if err != nil {
		return nil, err
	}
	postChildTable, err := postChildTableEditor.Table(ctx)
	if err != nil {
		return nil, err
	}
	return postChildTable.SetConstraintViolations(ctx, postChildCVMap)
}

// parentFkConstraintViolationsProcess handles processing the reference options on a child, or creating a violation if
// necessary.
func parentFkConstraintViolationsProcess(
	ctx context.Context,
	foreignKey doltdb.ForeignKey,
	postChild *constraintViolationsLoadedTable,
	postChildIndexPartialKey types.Tuple,
	postChildCVMapEditor *types.MapEditor,
	postChildTableEditor editor.TableEditor,
) error {
	mapIter := noms.NewNomsRangeReader(postChild.IndexSchema, postChild.IndexData,
		[]*noms.ReadRange{{Start: postChildIndexPartialKey, Inclusive: true, Reverse: false, Check: func(tuple types.Tuple) (bool, error) {
			return tuple.StartsWith(postChildIndexPartialKey), nil
		}}})
	defer mapIter.Close(ctx)
	var postChildIndexRow row.Row
	var err error
	for postChildIndexRow, err = mapIter.ReadRow(ctx); err == nil; postChildIndexRow, err = mapIter.ReadRow(ctx) {
		postChildIndexKey, err := postChildIndexRow.NomsMapKey(postChild.IndexSchema).Value(ctx)
		if err != nil {
			return err
		}
		postChildRowKey, err := postChild.Index.ToTableTuple(ctx, postChildIndexKey.(types.Tuple), postChild.Table.Format())
		if err != nil {
			return err
		}
		postChildRowVal, ok, err := postChild.RowData.MaybeGetTuple(ctx, postChildRowKey)
		if err != nil {
			return err
		}
		if !ok {
			return fmt.Errorf("index %s on %s contains data that table does not", foreignKey.TableIndex, foreignKey.TableName)
		}
		switch foreignKey.OnDelete {
		case doltdb.ForeignKeyReferenceOption_DefaultAction,
			doltdb.ForeignKeyReferenceOption_Restrict,
			doltdb.ForeignKeyReferenceOption_NoAction:
			constraintViolationVals := []types.Value{types.Uint(schema.DoltConstraintViolationsTypeTag), types.Uint(1)}
			postChildRowKeySlice, err := postChildRowKey.AsSlice()
			if err != nil {
				return err
			}
			constraintViolationVals = append(constraintViolationVals, postChildRowKeySlice...)
			postChildRowValSlice, err := postChildRowVal.AsSlice()
			if err != nil {
				return err
			}
			constraintViolationVals = append(constraintViolationVals, postChildRowValSlice...)
			constraintViolationKey, err := types.NewTuple(postChild.Table.Format(), constraintViolationVals...)
			if err != nil {
				return err
			}
			constraintViolationVal, err := types.NewTuple(postChild.Table.Format(),
				types.Uint(schema.DoltConstraintViolationsInfoTag), types.String(foreignKey.Name))
			if err != nil {
				return err
			}
			postChildCVMapEditor.Set(constraintViolationKey, constraintViolationVal)
		case doltdb.ForeignKeyReferenceOption_Cascade:
			postChildRow, err := row.FromNoms(postChild.Schema, postChildRowKey, postChildRowVal)
			if err != nil {
				return err
			}
			err = postChildTableEditor.DeleteRow(ctx, postChildRow)
			if err != nil {
				return err
			}
		case doltdb.ForeignKeyReferenceOption_SetNull:
			postChildRowTaggedValues, err := row.TaggedValuesFromTupleKeyAndValue(postChildRowKey, postChildRowVal)
			if err != nil {
				return err
			}
			postChildOldRow, err := row.New(postChild.Table.Format(), postChild.Schema, postChildRowTaggedValues)
			if err != nil {
				return err
			}
			for _, tag := range postChild.Index.IndexedColumnTags() {
				postChildRowTaggedValues[tag] = types.NullValue
			}
			postChildNewRow, err := row.New(postChild.Table.Format(), postChild.Schema, postChildRowTaggedValues)
			if err != nil {
				return err
			}
			err = postChildTableEditor.UpdateRow(ctx, postChildOldRow, postChildNewRow, nil)
			if err != nil {
				return err
			}
		default:
			return fmt.Errorf("unknown reference option in %s.%s for ON DELETE", foreignKey.TableName, foreignKey.Name)
		}
	}
	if err != io.EOF {
		return err
	}
	return nil
}

// childFkConstraintViolations processes foreign key constraint violations for the child in a foreign key.
func childFkConstraintViolations(
	ctx context.Context,
	foreignKey doltdb.ForeignKey,
	postParent, preChild, postChild *constraintViolationsLoadedTable,
) (*doltdb.Table, error) {
	postParentIndexTags := postParent.Index.IndexedColumnTags()
	postChildIndexTags := postChild.Index.IndexedColumnTags()
	postChildCVMap, err := postChild.Table.GetConstraintViolations(ctx)
	if err != nil {
		return nil, err
	}
	postChildCVMapEditor := postChildCVMap.Edit()

	differ := diff.NewRowDiffer(ctx, preChild.Schema, postChild.Schema, 1024)
	defer differ.Close()
	differ.Start(ctx, preChild.RowData, postChild.RowData)
	for {
		diffSlice, hasMore, err := differ.GetDiffs(1, 10*time.Second)
		if err != nil {
			return nil, err
		}
		if len(diffSlice) != 1 {
			if hasMore {
				return nil, fmt.Errorf("no diff returned but should have errored earlier")
			}
			break
		}
		rowDiff := diffSlice[0]
		switch rowDiff.ChangeType {
		case types.DiffChangeAdded, types.DiffChangeModified:
			postChildRow, err := row.FromNoms(postChild.Schema, rowDiff.KeyValue.(types.Tuple), rowDiff.NewValue.(types.Tuple))
			if err != nil {
				return nil, err
			}
			hasNulls := false
			for _, tag := range postChildIndexTags {
				if postChildRowEntry, ok := postChildRow.GetColVal(tag); !ok || types.IsNull(postChildRowEntry) {
					hasNulls = true
					break
				}
			}
			if hasNulls {
				continue
			}

			postChildIndexPartialKey, err := row.ReduceToIndexPartialKey(postChild.Index, postChildRow)
			if err != nil {
				return nil, err
			}
			postChildIndexPartialKeySlice, err := postChildIndexPartialKey.AsSlice()
			if err != nil {
				return nil, err
			}
			for i := 0; i < len(postParentIndexTags); i++ {
				postChildIndexPartialKeySlice[2*i] = types.Uint(postParentIndexTags[i])
			}
			parentPartialKey, err := types.NewTuple(postChild.Table.Format(), postChildIndexPartialKeySlice...)
			if err != nil {
				return nil, err
			}
			err = childFkConstraintViolationsProcess(ctx, foreignKey, postParent, postChild, rowDiff, parentPartialKey, postChildCVMapEditor)
			if err != nil {
				return nil, err
			}
		case types.DiffChangeRemoved:
			// We don't do anything if a child row was removed
		default:
			return nil, fmt.Errorf("unknown diff change type")
		}
		if !hasMore {
			break
		}
	}
	postChildCVMap, err = postChildCVMapEditor.Map(ctx)
	if err != nil {
		return nil, err
	}
	return postChild.Table.SetConstraintViolations(ctx, postChildCVMap)
}

// childFkConstraintViolationsProcess handles processing the constraint violations for the child of a foreign key.
func childFkConstraintViolationsProcess(
	ctx context.Context,
	foreignKey doltdb.ForeignKey,
	postParent, postChild *constraintViolationsLoadedTable,
	rowDiff *diff2.Difference,
	parentPartialKey types.Tuple,
	postChildCVMapEditor *types.MapEditor,
) error {
	var mapIter table.TableReadCloser = noms.NewNomsRangeReader(postParent.IndexSchema, postParent.IndexData,
		[]*noms.ReadRange{{Start: parentPartialKey, Inclusive: true, Reverse: false, Check: func(tuple types.Tuple) (bool, error) {
			return tuple.StartsWith(parentPartialKey), nil
		}}})
	defer mapIter.Close(ctx)
	// If the row exists in the parent, then we don't need to do anything
	if _, err := mapIter.ReadRow(ctx); err != nil {
		if err != io.EOF {
			return err
		}
		constraintViolationVals := []types.Value{types.Uint(schema.DoltConstraintViolationsTypeTag), types.Uint(1)}
		postChildRowKeySlice, err := rowDiff.KeyValue.(types.Tuple).AsSlice()
		if err != nil {
			return err
		}
		constraintViolationVals = append(constraintViolationVals, postChildRowKeySlice...)
		postChildRowValSlice, err := rowDiff.NewValue.(types.Tuple).AsSlice()
		if err != nil {
			return err
		}
		constraintViolationVals = append(constraintViolationVals, postChildRowValSlice...)
		constraintViolationKey, err := types.NewTuple(postChild.Table.Format(), constraintViolationVals...)
		if err != nil {
			return err
		}
		constraintViolationVal, err := types.NewTuple(postChild.Table.Format(),
			types.Uint(schema.DoltConstraintViolationsInfoTag), types.String(foreignKey.Name))
		if err != nil {
			return err
		}
		postChildCVMapEditor.Set(constraintViolationKey, constraintViolationVal)
	}
	return nil
}

// newConstraintViolationsLoadedTable returns a *constraintViolationsLoadedTable. Returns false if the table was loaded
// but the index could not be found. If the table could not be found, then an error is returned.
func newConstraintViolationsLoadedTable(ctx context.Context, tblName, idxName string, root *doltdb.RootValue) (*constraintViolationsLoadedTable, bool, error) {
	tbl, trueTblName, ok, err := root.GetTableInsensitive(ctx, tblName)
	if err != nil {
		return nil, false, err
	}
	if !ok {
		return nil, false, doltdb.ErrTableNotFound
	}
	sch, err := tbl.GetSchema(ctx)
	if err != nil {
		return nil, false, err
	}
	rowData, err := tbl.GetRowData(ctx)
	if err != nil {
		return nil, false, err
	}
	idx, ok := sch.Indexes().GetByNameCaseInsensitive(idxName)
	if !ok {
		return &constraintViolationsLoadedTable{
			TableName: trueTblName,
			Table:     tbl,
			Schema:    sch,
			RowData:   rowData,
		}, false, nil
	}
	indexData, err := tbl.GetIndexRowData(ctx, idx.Name())
	if err != nil {
		return nil, false, err
	}
	return &constraintViolationsLoadedTable{
		TableName:   trueTblName,
		Table:       tbl,
		Schema:      sch,
		RowData:     rowData,
		Index:       idx,
		IndexSchema: idx.Schema(),
		IndexData:   indexData,
	}, true, nil
}
