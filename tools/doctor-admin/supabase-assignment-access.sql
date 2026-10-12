create table if not exists public.doctor_patient_assignments (
  patient_uid text primary key,
  doctor_uid text not null,
  updated_at timestamptz not null default now()
);

alter table public.doctor_patient_assignments enable row level security;
revoke all on public.doctor_patient_assignments from anon, authenticated;
grant all on public.doctor_patient_assignments to service_role;

create or replace function public.is_assigned_report_doctor(
  requested_patient_uid text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.jwt() ->> 'iss')
      = 'https://securetoken.google.com/e-clinic-book-c5ee1'
    and (select auth.jwt() ->> 'aud') = 'e-clinic-book-c5ee1'
    and (select auth.jwt() ->> 'app_role') = 'doctor'
    and exists (
      select 1
      from public.doctor_patient_assignments as assignment
      where assignment.patient_uid = requested_patient_uid
        and assignment.doctor_uid = (select auth.jwt() ->> 'sub')
    );
$$;

revoke all on function public.is_assigned_report_doctor(text) from public, anon;
grant execute on function public.is_assigned_report_doctor(text)
  to authenticated;

create or replace function public.is_own_patient_report(
  requested_patient_uid text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.jwt() ->> 'iss')
      = 'https://securetoken.google.com/e-clinic-book-c5ee1'
    and (select auth.jwt() ->> 'aud') = 'e-clinic-book-c5ee1'
    and (select auth.jwt() ->> 'role') = 'authenticated'
    and (select auth.jwt() ->> 'app_role') = 'patient'
    and requested_patient_uid = (select auth.jwt() ->> 'sub');
$$;

revoke all on function public.is_own_patient_report(text) from public, anon;
grant execute on function public.is_own_patient_report(text)
  to authenticated;

drop policy if exists "Doctors read lab reports" on storage.objects;
drop policy if exists "Assigned doctors read lab reports" on storage.objects;
drop policy if exists "Patients read own lab reports" on storage.objects;
create policy "Assigned doctors read lab reports"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'lab-reports'
  and (
    public.is_assigned_report_doctor((storage.foldername(name))[1])
    or public.is_own_patient_report((storage.foldername(name))[1])
  )
);

drop policy if exists "Doctors upload lab reports" on storage.objects;
drop policy if exists "Assigned doctors upload lab reports"
  on storage.objects;
drop policy if exists "Patients upload own lab reports" on storage.objects;
create policy "Assigned doctors upload lab reports"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'lab-reports'
  and (
    public.is_assigned_report_doctor((storage.foldername(name))[1])
    or public.is_own_patient_report((storage.foldername(name))[1])
  )
  and array_length(storage.foldername(name), 1) = 2
  and lower(storage.extension(name)) in ('pdf', 'jpg', 'jpeg', 'png')
);

drop policy if exists "Doctors remove their incomplete uploads"
  on storage.objects;
drop policy if exists "Assigned doctors remove their incomplete uploads"
  on storage.objects;
drop policy if exists "Patients remove own incomplete uploads"
  on storage.objects;
create policy "Assigned doctors remove their incomplete uploads"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'lab-reports'
  and (
    public.is_assigned_report_doctor((storage.foldername(name))[1])
    or public.is_own_patient_report((storage.foldername(name))[1])
  )
  and owner_id::text = (select auth.jwt() ->> 'sub')
);
