function [vol,res,xform] = load(fname)
	% Load a nii volume together with the spatial resolution and xform matrix
	%
	% If the NIFTI file's sform code is >0 OR if both the sform and qform codes are zero, then sform will be used
	% when returning the xform matrix
	%
	% Romesh Abeysuriya 2017
	assert(ischar(fname),'Input file name must be a string')
    fname = strtrim(fname);
	assert(logical(exist(fname,'file')),sprintf('Requested file "%s" could not be found',fname))

	nii = load_untouch_nii(fname); % Note that the volume returned by load_untouch_nii corresponds to the volume returned by FSL's read_avw
	nii = scale_image(nii);
	vol = double(nii.img);
	res = nii.hdr.dime.pixdim(2:5);

	if nii.hdr.hist.sform_code == 0 &&  nii.hdr.hist.qform_code == 0
		fprintf(2,'Warning - *NO* qform/sform header code is provided! Your NIFTI file is *not* usable without this information!\n')
	end

	if nii.hdr.hist.sform_code == 1
		fprintf(2,'Warning - sform code is 1 which suggests the NIFTI file may be in an unexpected coordinate system\n');
	end

	xform = eye(4);
	if nii.hdr.hist.sform_code > 0 || (nii.hdr.hist.sform_code == 0 && nii.hdr.hist.qform_code == 0)
		% Use SFORM
		xform(1,:) = nii.hdr.hist.srow_x;
		xform(2,:) = nii.hdr.hist.srow_y;
		xform(3,:) = nii.hdr.hist.srow_z;
	else
		% Use QFORM
		b = nii.hdr.hist.quatern_b;
		c = nii.hdr.hist.quatern_c;
		d = nii.hdr.hist.quatern_d;
        a = sqrt(1-b^2-c^2-d^2);
		R = [a^2+b^2-c^2-d^2  , 2*b*c-2*a*d     , 2*b*d+2*a*c;
		     2*b*c+2*a*d      , a^2-b^2+c^2-d^2 , 2*c*d-2*a*b;
		     2*b*d-2*a*c      , 2*c*d+2*a*b     , a^2-b^2-c^2+d^2;];
		xform(1,:) = [R(1,:)*nii.hdr.dime.pixdim(2) nii.hdr.hist.qoffset_x];
		xform(2,:) = [R(2,:)*nii.hdr.dime.pixdim(3) nii.hdr.hist.qoffset_y];
		xform(3,:) = [R(3,:)*nii.hdr.dime.pixdim(1)*nii.hdr.dime.pixdim(4) nii.hdr.hist.qoffset_z];
    end


function nii = scale_image(nii)
	% Apply the value scaling from xform_nii.m without the transformations
	if nii.hdr.dime.scl_slope ~= 0 & ismember(nii.hdr.dime.datatype, [2,4,8,16,64,256,512,768]) & (nii.hdr.dime.scl_slope ~= 1 | nii.hdr.dime.scl_inter ~= 0)
	  nii.img = nii.hdr.dime.scl_slope * double(nii.img) + nii.hdr.dime.scl_inter;
	end

	if nii.hdr.dime.scl_slope ~= 0 & ismember(nii.hdr.dime.datatype, [32,1792])
	  nii.img = nii.hdr.dime.scl_slope * double(nii.img) + nii.hdr.dime.scl_inter;
	end

