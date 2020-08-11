from setuptools import setup

setup(name='mvUtil',
      description='Miscellaneous code for Champs products',
      url='unknown',
      use_scm_version=True,
      setup_requires=['setuptools_scm'],
      author='Stephen Siu',
      author_email='stephen.siu@lexisnexis.com',
		package_data={
			'': ['*.tab','*.txt','*.cfg','*.pm','*.sas','*.xlsm'],
			'keatonCode/Cabell': ['*'],
				'keatonCode/Cabell/Testing': ['*'],
				'keatonCode/CPM': ['*.R','*.msg'],
				'keatonCode/Error_Check_PxDx': ['*.R'],
				'keatonCode/New_Script_KE': ['*.R'],
					'keatonCode/New_Script_KE/Unprojected': ['*.R'],
					'keatonCode/New_Script_KE/USPI': ['*.R'],
				'keatonCode/Tea_Leaves': ['*.R'],
			'projCode/src': ['dopatients.pl','multiBucket_ABCPM.pl','project_PAC.pl','sendemail.pl','*.sas'],
				'projCode/src/AdvisoryBoard': ['*'],
				'projCode/src/INA': ['*'],
				'projCode/src/Trending': ['*'],
			'rhopsonCode/utilities': ['*'],
		},
      packages=[
			'keatonCode/Cabell',
				'keatonCode/Cabell/Testing',
				'keatonCode/CPM',
				'keatonCode/Error_Check_PxDx',
				'keatonCode/New_Script_KE',
					'keatonCode/New_Script_KE/Unprojected',
					'keatonCode/New_Script_KE/USPI',
				'keatonCode/Tea_Leaves',
			'projCode/src',
				'projCode/src/AdvisoryBoard',
				'projCode/src/INA',
				'projCode/src/Trending',
			'rhopsonCode/utilities'
			],
      scripts=[
			'keatonCode/Cabell/Cabell_Create_Delivery_Folders',
				'keatonCode/CPM/INA_Setting_Comparison_CPM',
				'keatonCode/Error_Check_PxDx/Error_Check_PxDx_v1',
				'keatonCode/Error_Check_PxDx/Error_Check_PxDx_v1_HG',
				'keatonCode/New_Script_KE/QA_full_tab_new_KE_v3',
					'keatonCode/New_Script_KE/Unprojected/QA_KE_unprojected',
					'keatonCode/New_Script_KE/USPI/QA_full_tab_new_KE_USPI_Single_Bucket',
				'keatonCode/Tea_Leaves/codeGroupMembers_Check',
			'projCode/src/AdvisoryBoard/combine_inadirs.pl',
				'projCode/src/AdvisoryBoard/combinesummaries_input.pl',
				'projCode/src/AdvisoryBoard/comparesizes_input.pl',
				'projCode/src/INA/makeidlist',
				'projCode/src/mbSplitter.pl',
				'projCode/src/multiBucket.pl',
				'projCode/src/multiBucket_ABCPM.pl',
				'projCode/src/run_ABCPM.pl',
				'projCode/src/Trending/standard_trend',
				'projCode/src/Trending/standard_trend_co'
			],
      zip_safe=False)
