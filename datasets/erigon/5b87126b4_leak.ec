commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
commit 5b87126b4302a2794eca22651b69357122ae960e
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Wed Mar 31 09:03:25 2021 +0700

    context leak fix (#1632)

diff --git a/cmd/headers/download/downloader.go b/cmd/headers/download/downloader.go
index 1f7a3b9ee..c32a190bf 100644
--- a/cmd/headers/download/downloader.go
+++ b/cmd/headers/download/downloader.go
@@ -346,8 +346,8 @@ func (cs *ControlServerImpl) updateHead(ctx context.Context, height uint64, hash
 			Forks:   cs.forks,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.SetStatus(callCtx, statusMsg, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Update status message for the sentry", "error", err)
 	}
@@ -377,10 +377,7 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 					Data: b,
 				},
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
-			_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
-			if err != nil {
+			if err := sendMessageById(ctx, cs.sentryClient, &outreq); err != nil {
 				return fmt.Errorf("send header request: %v", err)
 			}
 		}
@@ -388,6 +385,13 @@ func (cs *ControlServerImpl) newBlockHashes(ctx context.Context, inreq *proto_se
 	return nil
 }
 
+func sendMessageById(ctx context.Context, sentryClient proto_sentry.SentryClient, outreq *proto_sentry.SendMessageByIdRequest) error {
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	_, err := sentryClient.SendMessageById(callCtx, outreq, &grpc.EmptyCallOption{})
+	return err
+}
+
 func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sentry.InboundMessage) error {
 	rlpStream := rlp.NewStream(bytes.NewReader(inreq.Data), uint64(len(inreq.Data)))
 	_, err := rlpStream.List()
@@ -425,8 +429,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -438,8 +442,8 @@ func (cs *ControlServerImpl) blockHeaders(ctx context.Context, inreq *proto_sent
 		PeerId:   inreq.PeerId,
 		MinBlock: heighestBlock,
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -475,8 +479,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 				PeerId:  inreq.PeerId,
 				Penalty: proto_sentry.PenaltyKind_Kick, // TODO: Extend penalty kinds
 			}
-			//nolint:govet
-			callCtx, _ := context.WithCancel(ctx)
+			callCtx, cancel := context.WithCancel(ctx)
+			defer cancel()
 			if _, err1 := cs.sentryClient.PenalizePeer(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 				log.Error("Could not send penalty", "err", err1)
 			}
@@ -489,8 +493,8 @@ func (cs *ControlServerImpl) newBlock(ctx context.Context, inreq *proto_sentry.I
 		PeerId:   inreq.PeerId,
 		MinBlock: request.Block.NumberU64(),
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err1 := cs.sentryClient.PeerMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{}); err1 != nil {
 		log.Error("Could not send min block for peer", "err", err1)
 	}
@@ -661,8 +665,8 @@ func (cs *ControlServerImpl) getBlockHeaders(ctx context.Context, inreq *proto_s
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send header response: %v", err)
@@ -717,8 +721,8 @@ func (cs *ControlServerImpl) getBlockBodies(ctx context.Context, inreq *proto_se
 			Data: b,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	_, err = cs.sentryClient.SendMessageById(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err != nil {
 		return fmt.Errorf("send bodies response: %v", err)
@@ -783,8 +787,8 @@ func (cs *ControlServerImpl) sendHeaderRequest(ctx context.Context, req *headerd
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send header request", "err", err1)
@@ -812,8 +816,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 			Data: bytes,
 		},
 	}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	sentPeers, err1 := cs.sentryClient.SendMessageByMinBlock(callCtx, &outreq, &grpc.EmptyCallOption{})
 	if err1 != nil {
 		log.Error("Could not send block bodies request", "err", err1)
@@ -827,8 +831,8 @@ func (cs *ControlServerImpl) sendBodyRequest(ctx context.Context, req *bodydownl
 
 func (cs *ControlServerImpl) penalise(ctx context.Context, peer []byte) {
 	penalizeReq := proto_sentry.PenalizePeerRequest{PeerId: gointerfaces.ConvertBytesToH512(peer), Penalty: proto_sentry.PenaltyKind_Kick}
-	//nolint:govet
-	callCtx, _ := context.WithCancel(ctx)
+	callCtx, cancel := context.WithCancel(ctx)
+	defer cancel()
 	if _, err := cs.sentryClient.PenalizePeer(callCtx, &penalizeReq, &grpc.EmptyCallOption{}); err != nil {
 		log.Error("Could not penalise", "peer", peer, "error", err)
 	}
diff --git a/gointerfaces/sentry/sentry_grpc.pb.go b/gointerfaces/sentry/sentry_grpc.pb.go
index 2776abc4c..2d5224417 100644
--- a/gointerfaces/sentry/sentry_grpc.pb.go
+++ b/gointerfaces/sentry/sentry_grpc.pb.go
@@ -3,11 +3,12 @@
 package sentry
 
 import (
-	context "context"
-	grpc "google.golang.org/grpc"
-	codes "google.golang.org/grpc/codes"
-	status "google.golang.org/grpc/status"
-	emptypb "google.golang.org/protobuf/types/known/emptypb"
+	"context"
+
+	"google.golang.org/grpc"
+	"google.golang.org/grpc/codes"
+	"google.golang.org/grpc/status"
+	"google.golang.org/protobuf/types/known/emptypb"
 )
 
 // This is a compile-time assertion to ensure that this generated file
