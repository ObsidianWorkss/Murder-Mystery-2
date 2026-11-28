-- Test production per-round movement policy and correlated-ray aim adaptation.
local State={
    Config={SelfLearningAim=true},
    StyleMoves={SelfLearner={Sessions=1}},
    AimObservationDelay=function() return 0.1,"ObservedAge" end,
    AimLearning={Rows={},Observed=0,Hits=0,Misses=0,Unknown=0,
        Serial=0,Round=0,RoundObserved=0,RoundHits=0,RoundMisses=0,Last="None"},
}
local learningFile="MM2Universal/learning-v1.json"
local learningLoadStatus="Test learning storage"
local savedPayload,writeCount,savedPath=nil,0,nil
local learningHttp={
    JSONEncode=function(_,payload)
        savedPayload=payload
        return "test-encoded-model"
    end,
}
local isfolder=function() return true end
local writefile=function(path,data)
    savedPath=path
    assert(data=="test-encoded-model")
    writeCount+=1
end
-- INSERT_SPACE_DURATION
-- INSERT_IMPORT_RL_ROWS
-- INSERT_RL_POLICY
-- INSERT_SAVE_POLICY
-- INSERT_GUN_LEAD
-- INSERT_AIM_RECORDER

local passed=0
local function check(label,condition)
    assert(condition,label)
    passed+=1
end
local function approx(label,actual,expected)
    check(label,math.abs(actual-expected)<0.00001)
end

check("role and threat density affect contextual juke learning",
    styleRLContext("Murderer","Open",8,1)=="Attacker/Open/Close/Solo")
check("crowded corner gets independent learning context",
    styleRLContext("Innocent","Corner",13,2)=="Defender/Corner/Approach/Crowd")
local actions=styleRLActions("Open",true)
check("open space can explore bounded alternative feints",#actions==3 and actions[3]=="Feint")
check("narrow corridors exclude risky repeated feints",#styleRLActions("Narrow",true)==2)
local rows={}
local key="Defender/Open/Close/Solo"
check("first juke uses known balanced baseline",styleRLChoose(rows,key,actions)=="Balanced")
check("unobserved reward does not count",not styleRLUpdate(rows,key,"Balanced",nil,1))
check("out of range reward does not count",not styleRLUpdate(rows,key,"Balanced",0,1))
check("unknown pattern cannot poison learning",not styleRLUpdate(rows,key,"Teleport",1,1))
for i=1,3 do check("baseline observation "..i,styleRLUpdate(rows,key,"Balanced",1,i)) end
check("after three baseline results, try bounded alternative",styleRLChoose(rows,key,actions)=="Snap")
check("negative results update the observed alternative",styleRLUpdate(rows,key,"Snap",-1,4))
check("previously untried feint is next",styleRLChoose(rows,key,actions)=="Feint")
check("feint outcome is tracked",styleRLUpdate(rows,key,"Feint",1,5))
check("all actions have observations",rows[key].Arms.Balanced.N==3
    and rows[key].Arms.Snap.N==1 and rows[key].Arms.Feint.N==1)
check("safe corridor never chooses a disallowed feint",
    styleRLChoose(rows,key,{"Balanced","Snap"})~="Feint")
local changed,duration=styleRLApply("Snap","Fake cut",0.4,7,16,true,"Open")
check("snap changes to a direct cut",changed=="Quick cut")
check("snap shortens timing without changing walk speed",duration<0.4 and duration>0.25)
local feint,feintDuration=styleRLApply("Feint","Quick cut",0.3,7,16,true,"Open")
check("feint selects fake cut only in safe open space",
    feint=="Fake cut" and feintDuration>=0.3)
local narrow=styleRLApply("Feint","Tight cut",0.24,3,16,false,"Narrow")
check("learner never forces fake cut in narrow corridor",narrow=="Tight cut")
local noRoute=styleRLApply("Snap","Fake cut",0.2,1,16,true,"Open")
check("learner cannot override blocked route",noRoute==nil)

local reward,reason=styleRLGrade(true,false,false,12,16,2,1.1,true)
check("observed directional separation can be a positive proxy",
    reward==1 and reason=="Observed separation improved")
reward,reason=styleRLGrade(true,false,false,12,16,2,1.1,true,true)
check("distance gained while sheriff can still shoot is not a successful dodge",
    reward==nil and reason=="Ranged shooter still has line of sight")
reward=styleRLGrade(true,false,false,12,16,2,1.1,true,false)
check("observed separation behind cover may still receive a cautious positive reward",
    reward==1)
reward=styleRLGrade(true,true,false,12,16,2,1.1,true)
check("blocking obstacle is a negative proxy",reward==-1)
reward=styleRLGrade(false,false,true,12,10,1,0.8,true)
check("nearby death is a negative proxy",reward==-1)
reward=styleRLGrade(true,false,false,12,16,0.2,1.1,true)
check("movement without meaningful own displacement is unknown",reward==nil)
reward=styleRLGrade(true,false,false,12,16,2,1.1,false)
check("opponent identity changed is unknown",reward==nil)
reward=styleRLGrade(true,false,false,12,16,2,2.1,true)
check("stale outcomes are not learned",reward==nil)

local near={Mode="Moving",Distance=11}
local lead,source,action,context=State.GunPredictionLead(nil,near)
approx("initial aim retains network baseline",lead,0.1)
check("gun learner starts balanced",action=="Balanced" and context=="Moving/Near"
    and source=="ObservedAge")
check("stationary target always has zero lead",State.GunPredictionLead(nil,{Stationary=true})==0)
local pending={AimLearningContext="Moving/Near",AimLearningAction="Balanced"}
check("missing correlation never rewards a shot",
    State.RecordAimLearning(pending,true,nil,"Ambiguous")==false)
check("obstructed ray is not a false prediction miss",
    State.RecordAimLearning(pending,false,{Name="Wall"},"Heuristic")==false)
check("missing aim action is ignored",
    State.RecordAimLearning({AimLearningContext="Moving/Near"},true,nil,"Heuristic")==false)
for i=1,3 do check("matched reported body ray learned "..i,
    State.RecordAimLearning(pending,true,{}, "Heuristic")==true) end
lead,source,action,context=State.GunPredictionLead(nil,near)
approx("short lead exploration stays within 8 percent",lead,0.092)
check("short lead selected after minimum observations",action=="Short")
check("matched ray-miss grades short variant",
    State.RecordAimLearning({AimLearningContext=context,AimLearningAction=action},
        false,nil,"Heuristic")==true)
lead,source,action=State.GunPredictionLead(nil,near)
approx("long lead also bounded within 8 percent",lead,0.108)
check("unused long action is explored",action=="Long")
check("reported ray miss is not labelled as a confirmed kill",
    State.AimLearning.Last=="Reported gun ray missed intended body")
check("observed ray counts separate hits and misses",
    State.AimLearning.Observed==4 and State.AimLearning.Hits==3
        and State.AimLearning.Misses==1 and State.AimLearning.Unknown==2)
State.Config.SelfLearningAim=false
local disabled,reason=State.RecordAimLearning(pending,true,{},"Heuristic")
check("toggle stops further learning immediately",not disabled and reason=="Uncertain or disabled")
approx("disabled learner uses baseline prediction",State.GunPredictionLead(nil,near),0.1)
State.Config.SelfLearningAim=true
local snapshot=State.GetAimLearningSnapshot()
check("per-round counters visible",snapshot.RoundObserved==4 and snapshot.Contexts==1)
State.StyleMoves.SelfLearner.Sessions=2
snapshot=State.GetAimLearningSnapshot()
check("new match resets only round counters, not learned policy",
    snapshot.RoundObserved==0 and snapshot.Observed==4 and snapshot.Contexts==1)
for i=1,70 do styleRLUpdate(rows,"context"..i,"Balanced",1,i+100) end
local bounded=0
for _ in pairs(rows) do bounded+=1 end
check("learned contexts are limited in memory",bounded<=48)

local imported=importRLRows({
    Valid={At=12,Arms={Balanced={N=1000,Q=0.75},Snap={N=2,Q=-0.3},
        Teleport={N=200,Q=1}}},
    Bad={At=5,Arms={Balanced={N=3,Q=200}}},
    Invalid={At=4,Arms={Balanced={N=0/0,Q=0.4}}},
}, {"Balanced","Snap","Feint"})
check("import accepts only known bounded actions",imported.Valid.N==50
    and imported.Valid.Arms.Teleport==nil and imported.Valid.Arms.Balanced.N==48)
check("import ignores invalid or poisoned model rows",
    imported.Bad==nil and imported.Invalid==nil)
check("import preserves legitimate value estimates",
    imported.Valid.Arms.Snap.Q==-0.3)

local persisted=State.SaveLearning(true)
local baselineWrites=writeCount
check("safe storage writes a model only when available",
    persisted and State.LearningStorage.Status=="Local learning saved")
check("saved model contains both juke and aim context tables",
    savedPayload.Schema==1 and savedPayload.Juke==State.StyleMoves.SelfLearner.Rows
        and savedPayload.Aim==State.AimLearning.Rows)
check("model is saved beneath the existing MM2Universal folder",
    savedPath=="MM2Universal/learning-v1.json")
check("repeated automatic writes are throttled",
    not State.SaveLearning(false) and writeCount==baselineWrites)
check("explicit end-of-round flush overrides rate limit",
    State.SaveLearning(true) and writeCount==baselineWrites+1)
State.LearningStorage.Available=false
check("client without file API retains session learning",
    not State.SaveLearning(true)
        and State.LearningStorage.Status:find("session",1,true)~=nil)

print(("%d round-learning and aim-policy assertions passed"):format(passed))
