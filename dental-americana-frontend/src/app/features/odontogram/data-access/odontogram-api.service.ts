import{HttpClient}from'@angular/common/http';import{inject,Injectable}from'@angular/core';import{DentitionType,Odontogram,ToothCondition,ToothSurface,TreatmentState}from'../models/odontogram.models';
@Injectable({providedIn:'root'})export class OdontogramApiService{private readonly http=inject(HttpClient);private readonly base='/api/v1';
 list(encounterId:number){return this.http.get<Odontogram[]>(`${this.base}/odontograms`,{params:{encounterId}});}
 initialize(encounterId:number,dentitionType:DentitionType){return this.http.post<Odontogram>(`${this.base}/clinical-encounters/${encounterId}/odontograms`,{dentitionType,generalObservation:null,professionalConfirmation:true});}
 observe(id:number,generalObservation:string,version:number){return this.http.put<Odontogram>(`${this.base}/odontograms/${id}/observation`,{generalObservation,version,professionalConfirmation:true});}
 addFinding(id:number,payload:{tooth:string;surface:ToothSurface;condition:ToothCondition;treatmentState:TreatmentState;observation:string|null}){return this.http.post<Odontogram>(`${this.base}/odontograms/${id}/findings`,{...payload,professionalConfirmation:true});}
 removeFinding(id:number,findingId:number,version:number){return this.http.patch<Odontogram>(`${this.base}/odontograms/${id}/findings/${findingId}/remove`,{version,professionalConfirmation:true});}
 approve(id:number,version:number){return this.http.post<Odontogram>(`${this.base}/odontograms/${id}/approve`,{version,professionalConfirmation:true});}}
