# every module F ships but its host and the two runtimes over it is pure:
# near-bend's near-function.bend checked these (its f.bend, its deployment
# and its AI and Dot entries), and the four Dot modules only its hub.bend
# imported join them, with no unsafe or foreign code
import Base
import ../../bend2/std/F/ui/primitives.bend as Primitives
import ../../bend2/std/F/ui/tokens.bend as Tokens
import ../../bend2/std/F/ui/metrics.bend as Metrics
import ../../bend2/std/F/ui/kit.bend as Kit
import ../../bend2/std/F/ui/symbols.bend as Symbols
import ../../bend2/std/F/ui/nearling.bend as Nearling
import ../../bend2/std/F/ai/ai-sdk.bend as AI
import ../../bend2/std/F/dot/session.bend as Dot
import ../../bend2/std/F/dot/agent.bend as Agent
import ../../bend2/std/F/dot/native.bend as Voice
import ../../bend2/std/F/dot/attachments.bend as Attachments
import ../../bend2/std/F/dot/vision.bend as Vision
import ../../bend2/std/F/deployment/general/rose/PROOF.bend as Rose
import ../../bend2/std/F/deployment/domain/architecture/PROOF.bend as Architecture
import ../../bend2/std/F/deployment/domain/architecture/system/ops.bend as System
import ../../bend2/std/F/deployment/domain/architecture/system/plan/ops.bend as Plan
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/ops.bend as Deployment
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/azure/ops.bend as Azure
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/nix_darwin/ops.bend as NixDarwin
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/launchd/ops.bend as Launchd
import ../../bend2/std/F/deployment/domain/architecture/view/ops.bend as View
import ../../bend2/std/F/deployment/source/type.bend as Source
import ../../bend2/std/F/deployment/source/ops.bend as SourceChecks

#|ALL PROOFS CHECK
#|Use --verdict for mathematical validity.
