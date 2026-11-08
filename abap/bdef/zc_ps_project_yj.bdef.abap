projection;
strict ( 2 );
use draft;

define behavior for ZC_PS_PROJECT_YJ alias Project
{
  use create;
  use update;

  use action Edit;
  use action Activate;
  use action Discard;
  use action Resume;
  use action Prepare;

  use association _Wbs { create; with draft; }
}

define behavior for ZC_PS_WBS_YJ alias Wbs
{
  use update;

  use association _Project { with draft; }
}
