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

package sqle

import (
	"context"

	"github.com/dolthub/dolt/go/libraries/doltcore/doltdb"
	"github.com/dolthub/dolt/go/libraries/doltcore/env"
	"github.com/dolthub/dolt/go/libraries/doltcore/ref"
	"github.com/dolthub/dolt/go/store/hash"
)

// SessionRepoStateReader is an adapter for env.RepoStateReader in SQL contexts, getting information about the repo state
// from the session.
type SessionRepoStateReader struct {
	session *DoltSession
	dbName string
}

func (s SessionRepoStateReader) StagedRoot(ctx context.Context) (*doltdb.RootValue, error) {
	panic("staged root not in session yet")
}

func (s SessionRepoStateReader) WorkingRoot(ctx context.Context) (*doltdb.RootValue, error) {
	return s.session.roots[s.dbName].root, nil
}

var _ env.RepoStateReader = SessionRepoStateReader{}

func NewSessionRepoStateReader(session *DoltSession, dbName string) SessionRepoStateReader {
	return SessionRepoStateReader{session: session, dbName: dbName}
}

func (s SessionRepoStateReader) CWBHeadRef() ref.DoltRef {
	workingSet := s.session.workingSets[s.dbName]
	headRef, err := workingSet.ToHeadRef()
	// TODO: fix this interface
	if err != nil {
		panic(err)
	}
	return headRef
}

func (s SessionRepoStateReader) CWBHeadSpec() *doltdb.CommitSpec {
	// TODO: get rid of this
	ref := s.CWBHeadRef()
	spec, err := doltdb.NewCommitSpec(ref.GetPath())
	if err != nil {
		panic(err)
	}
	return spec
}

func (s SessionRepoStateReader) CWBHeadHash(ctx context.Context) (hash.Hash, error) {
	// TODO: get rid of this
	panic("implement me")
}

func (s SessionRepoStateReader) StagedHash() hash.Hash {
	panic("implement me")
}

func (s SessionRepoStateReader) IsMergeActive(ctx context.Context) (bool, error) {
	panic("implement me")
}

func (s SessionRepoStateReader) GetMergeCommit(ctx context.Context) (*doltdb.Commit, error) {
	panic("implement me")
}

func (s SessionRepoStateReader) GetPreMergeWorking(ctx context.Context) (*doltdb.RootValue, error) {
	panic("implement me")
}

