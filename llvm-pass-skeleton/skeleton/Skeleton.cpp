#include "llvm/Pass.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Transforms/Scalar/LoopPassManager.h"
#include <llvm/Analysis/IVDescriptors.h>
#include <llvm/IR/BasicBlock.h>
#include "llvm/IR/Dominators.h"
#include "llvm/IR/CFG.h"
#include "llvm/Analysis/AliasAnalysis.h"
using namespace llvm;

namespace {
struct MyLICMPass : public PassInfoMixin<MyLICMPass> {
    PreservedAnalyses run(Loop &L, LoopAnalysisManager &AM,
                          LoopStandardAnalysisResults &AR, LPMUpdater &) {
        BasicBlock *Preheader = L.getLoopPreheader();
        bool Changed = false;
        
        if (Preheader) {
            errs() << "Loop Preheader in function: " << L.getHeader()->getParent()->getName() << "\n";
            errs() << "  Preheader: " << Preheader->getName() << "\n";
        } else {
            errs() << "No Preheader found in function: " << L.getHeader()->getParent()->getName() << "\n";
            return PreservedAnalyses::all();
        }

        std::vector<Instruction*> LoopInvariantInstructions;
        
        DominatorTree &DT = AR.DT;
        AliasAnalysis &AA = AR.AA; //TODO: Do I need Alias analysis for anything? I feel like i do
        
        for (BasicBlock *BB : L.blocks()) {
            for (Instruction &I : *BB) {
                for (Use &U : I.operands()) {
                    Value *Op = U.get(); //TODO; Do I need anything for Use or Value? If not delete these 
                    if (isLoopInv(I, L, DT)) {
                        LoopInvariantInstructions.push_back(&I);
                        errs() << "  Found loop-invariant instruction: " << I << "\n";
                        break;
                      }
                  }
            }
        }
        
        Instruction *Term = Preheader->getTerminator();
        for (Instruction *LI : LoopInvariantInstructions) { //TODO: Double check that this removing stuff actually works lol 
            LI->removeFromParent();
            LI->insertBefore(Term->getIterator());
            Changed = true;
        }
        return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
    }

    bool isLoopInv(Instruction &I, Loop &L, DominatorTree &DT) { //TODO makes sense but a bit paranoid, look up conditions for a loop invariant
        if (I.isTerminator()) return false; //checks if term, side effects, store/load 
        if (I.mayHaveSideEffects()) return false;
        if (I.mayReadOrWriteMemory()) return false;

        for (Value *Op : I.operands()) {
            if (Instruction *OpI = dyn_cast<Instruction>(Op)) {
                if (L.contains(OpI)) //Checks if its used in the loop
                    return false; 
            }
        }

        BasicBlock *Preheader = L.getLoopPreheader();
        if (!Preheader) //Does the loop have a preheader
            return false;

        if (!DT.dominates(Preheader, I.getParent())) //Is the instruction dominated by the preheader
            return false;

        return true;
    }
};
}

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
    return {
        LLVM_PLUGIN_API_VERSION, "Skeleton pass", "v0.1",
        [](PassBuilder &PB) {
            PB.registerPipelineStartEPCallback(
                [](ModulePassManager &MPM, OptimizationLevel Level) {
                    FunctionPassManager FPM;
                    
                    LoopPassManager LPM;
                    LPM.addPass(MyLICMPass());

                    //loops exist inside functions
                    FPM.addPass(createFunctionToLoopPassAdaptor(std::move(LPM)));
                    // functions exist inside modules
                    MPM.addPass(createModuleToFunctionPassAdaptor(std::move(FPM)));
                });
        }
    };
}

